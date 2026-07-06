#include "meme_llm.h"

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#ifdef MLLM_STUB
void* mllm_init(const char*, const char*, int, int, int, int, const char*) { return NULL; }
char* mllm_complete(void*, const char*, int, float) { return NULL; }
char* mllm_multimodal_complete(void*, const char*, const unsigned char*, size_t, int, int, int, float) { return NULL; }
int mllm_complete_stream(void*, const char*, int, float, void*, void*) { return 1; }
void mllm_close(void*) {}
void mllm_free_string(char*) {}
void mllm_log_to_file(int, const char*, ...) {}
#else

#include "llama.h"
#include "mtmd.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>
#include <string>
#include <stdarg.h>
#include <pthread.h>
#include <sys/time.h>
#include <android/log.h>

// ---- 日志文件输出 ----
// 全局 FILE* + 互斥锁，避免多线程竞争；只在 Android 上启用（与 __android_log_print 对应）。
// 文件格式：每行 "I/W/E HH:MM:SS.mmm <msg>\n"，便于 LogService 按行解析。
static FILE* g_log_file = nullptr;
static pthread_mutex_t g_log_file_mutex = PTHREAD_MUTEX_INITIALIZER;

extern "C" void mllm_log_to_file(int level, const char* fmt, ...) {
    FILE* f = g_log_file;
    if (!f) return;
    const char* prefix = (level == 2) ? "E" : (level == 1) ? "W" : "I";
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    struct tm tm_buf;
    localtime_r(&tv.tv_sec, &tm_buf);
    char ts[32];
    strftime(ts, sizeof(ts), "%H:%M:%S", &tm_buf);
    pthread_mutex_lock(&g_log_file_mutex);
    fprintf(f, "%s %s.%03ld ", prefix, ts, (long)tv.tv_usec / 1000);
    va_list ap;
    va_start(ap, fmt);
    vfprintf(f, fmt, ap);
    va_end(ap);
    fputc('\n', f);
    fflush(f);
    pthread_mutex_unlock(&g_log_file_mutex);
}

static void open_log_file(const char* path) {
    if (!path) return;
    g_log_file = fopen(path, "a");
    if (g_log_file) {
        struct timeval tv;
        gettimeofday(&tv, nullptr);
        fprintf(g_log_file, "=== mllm session start, path=%s, ts=%ld.%06ld ===\n",
                path, (long)tv.tv_sec, (long)tv.tv_usec);
        fflush(g_log_file);
    }
}

static void close_log_file() {
    if (!g_log_file) return;
    pthread_mutex_lock(&g_log_file_mutex);
    fclose(g_log_file);
    g_log_file = nullptr;
    pthread_mutex_unlock(&g_log_file_mutex);
}

// 过滤掉 llama.cpp 加载阶段过于啰嗦的日志（保留到常量数组便于维护）
static const char* const k_llama_log_blacklist[] = {
    "llama_model_loader",   // 模型元数据 kv dump（动辄几十行）
    "load_tensors",         // 张量加载进度（每个 tensor 一行，几百个 tensor）
    "create_tensor",        // 每个 tensor 创建日志，模型有几百个 tensor，过于啰嗦
};
static bool llama_log_is_filtered(const char* text) {
    if (!text) return true;
    for (const char* needle : k_llama_log_blacklist) {
        if (strstr(text, needle) != nullptr) return true;
    }
    return false;
}

// llama.cpp 内部日志回调：重定向到我们的日志宏
static void llama_log_callback(enum ggml_log_level level, const char* text, void* /*user_data*/) {
    if (llama_log_is_filtered(text)) return;
    switch (level) {
        case GGML_LOG_LEVEL_ERROR: MLLM_LOGE("[llama] %s", text); break;
        case GGML_LOG_LEVEL_WARN:  MLLM_LOGW("[llama] %s", text); break;
        default:                   MLLM_LOGI("[llama] %s", text); break;
    }
}

typedef struct {
    llama_model*   model;
    llama_context* ctx;
    llama_sampler* sampler;
    const llama_vocab* vocab;
    mtmd_context*  mtmd_ctx;
    int n_threads;
} MllmHandle;

void* mllm_init(const char* model_path,
                const char* mmproj_path,
                int n_threads,
                int n_ctx,
                int use_gpu,
                int n_gpu_layers,
                const char* log_file_path) {
    open_log_file(log_file_path);

    // 注册 llama.cpp 日志回调，捕获其内部日志到 logcat + 日志文件
    llama_log_set(llama_log_callback, NULL);
    ggml_log_set(llama_log_callback, NULL);

    MLLM_LOGI("mllm_init: model_path=%s, threads=%d, ctx=%d, use_gpu=%d, n_gpu_layers=%d",
              model_path, n_threads, n_ctx, use_gpu, n_gpu_layers);

    ggml_backend_load_all();

    // --- GPU 检测日志 ---
    int n_backends = (int)ggml_backend_reg_count();
    int n_devices = (int)ggml_backend_dev_count();
    MLLM_LOGI("mllm_init: ggml_backend_load_all() 完成, backends=%d, devices=%d", n_backends, n_devices);
    for (int i = 0; i < n_backends; i++) {
        ggml_backend_reg_t reg = ggml_backend_reg_get(i);
        size_t n_reg_dev = ggml_backend_reg_dev_count(reg);
        MLLM_LOGI("  backend[%d]: \"%s\" (%zu devices)", i, ggml_backend_reg_name(reg), n_reg_dev);
        for (size_t j = 0; j < n_reg_dev; j++) {
            ggml_backend_dev_t dev = ggml_backend_reg_dev_get(reg, j);
            const char* dev_name = ggml_backend_dev_name(dev);
            const char* dev_desc = ggml_backend_dev_description(dev);
            MLLM_LOGI("    device[%zu]: \"%s\" — %s", j, dev_name, dev_desc);
        }
    }
    MLLM_LOGI("mllm_init: use_gpu=%d, n_gpu_layers=%d", use_gpu, n_gpu_layers);

    llama_model_params model_params = llama_model_default_params();
    if (use_gpu && n_devices > 0) {
        model_params.n_gpu_layers = n_gpu_layers;
        MLLM_LOGI("mllm_init: GPU 加速已启用, n_gpu_layers=%d", n_gpu_layers);
    } else if (use_gpu && n_devices == 0) {
        MLLM_LOGW("mllm_init: 请求 GPU 加速但未检测到 GPU 设备，回退到 CPU");
        model_params.n_gpu_layers = 0;
    } else {
        model_params.n_gpu_layers = 0;
    }
    llama_model* model = llama_model_load_from_file(model_path, model_params);
    if (!model) {
        MLLM_LOGE("mllm_init: failed to load model from %s", model_path);
        return NULL;
    }

    const llama_vocab* vocab = llama_model_get_vocab(model);

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx   = n_ctx;
    ctx_params.n_batch = n_ctx < 512 ? n_ctx : 512;
    ctx_params.n_ubatch = 256;
    ctx_params.type_k = GGML_TYPE_F16;
    ctx_params.type_v = GGML_TYPE_F16;
    ctx_params.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;

    llama_context* ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        MLLM_LOGE("mllm_init: failed to create context");
        llama_model_free(model);
        return NULL;
    }

    auto sparams = llama_sampler_chain_default_params();
    llama_sampler* sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.0f));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    mtmd_context* mtmd_ctx = NULL;
    if (mmproj_path) {
        MLLM_LOGI("mllm_init: loading mtmd from %s", mmproj_path);
        auto mtmd_params = mtmd_context_params_default();
        mtmd_params.use_gpu = (use_gpu && n_devices > 0);
        mtmd_params.n_threads = n_threads;
        mtmd_ctx = mtmd_init_from_file(mmproj_path, model, mtmd_params);
        if (!mtmd_ctx) {
            MLLM_LOGW("mllm_init: failed to init mtmd from %s (non-fatal)", mmproj_path);
        } else {
            MLLM_LOGI("mllm_init: mtmd initialized successfully");
        }
    } else {
        MLLM_LOGI("mllm_init: no mmproj_path provided, mtmd not initialized");
    }

    MllmHandle* handle = (MllmHandle*)calloc(1, sizeof(MllmHandle));
    handle->model    = model;
    handle->ctx      = ctx;
    handle->sampler  = sampler;
    handle->vocab    = vocab;
    handle->mtmd_ctx = mtmd_ctx;
    handle->n_threads = n_threads;
    return handle;
}

static char* run_sample_loop(MllmHandle* handle,
                             llama_token* tokens,
                             int n_tokens,
                             int max_tokens,
                             float temperature) {
    if (temperature > 0.0f) {
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    } else {
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_greedy());
    }

    llama_batch batch = llama_batch_get_one(tokens, n_tokens);
    std::string result;

    for (int n_pos = 0; n_pos + batch.n_tokens < n_tokens + max_tokens; ) {
        if (llama_decode(handle->ctx, batch)) {
            MLLM_LOGE("run_sample_loop: llama_decode failed");
            break;
        }
        n_pos += batch.n_tokens;

        llama_token new_token = llama_sampler_sample(handle->sampler, handle->ctx, -1);
        llama_sampler_accept(handle->sampler, new_token);

        if (llama_vocab_is_eog(handle->vocab, new_token)) {
            break;
        }

        char buf[256];
        int n = llama_token_to_piece(handle->vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            result.append(buf, n);
        }

        batch = llama_batch_get_one(&new_token, 1);
    }

    // 重置 sampler：删除动态添加的采样器，保留初始的 temp(0)+dist
    while (llama_sampler_chain_n(handle->sampler) > 2) {
        llama_sampler* removed = llama_sampler_chain_remove(handle->sampler, llama_sampler_chain_n(handle->sampler) - 1);
        llama_sampler_free(removed);
    }

    char* ret = (char*)malloc(result.size() + 1);
    memcpy(ret, result.c_str(), result.size());
    ret[result.size()] = '\0';
    return ret;
}

static int run_stream_loop(MllmHandle* handle,
                           llama_token* tokens,
                           int n_tokens,
                           int max_tokens,
                           float temperature,
                           mllm_token_callback_t callback,
                           void* user_data) {
    if (!callback) return 1;

    if (temperature > 0.0f) {
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    } else {
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_greedy());
    }

    llama_batch batch = llama_batch_get_one(tokens, n_tokens);

    for (int n_pos = 0; n_pos + batch.n_tokens < n_tokens + max_tokens; ) {
        if (llama_decode(handle->ctx, batch)) {
            MLLM_LOGE("run_stream_loop: llama_decode failed");
            return 1;
        }
        n_pos += batch.n_tokens;

        llama_token new_token = llama_sampler_sample(handle->sampler, handle->ctx, -1);
        llama_sampler_accept(handle->sampler, new_token);

        if (llama_vocab_is_eog(handle->vocab, new_token)) {
            break;
        }

        char buf[256];
        int n = llama_token_to_piece(handle->vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            buf[n] = '\0';
            if (callback(buf, user_data) != 0) {
                break;
            }
        }

        batch = llama_batch_get_one(&new_token, 1);
    }

    while (llama_sampler_chain_n(handle->sampler) > 2) {
        llama_sampler* removed = llama_sampler_chain_remove(handle->sampler, llama_sampler_chain_n(handle->sampler) - 1);
        llama_sampler_free(removed);
    }

    return 0;
}

int mllm_complete_stream(void* handle_ptr,
                         const char* prompt,
                         int max_tokens,
                         float temperature,
                         mllm_token_callback_t callback,
                         void* user_data) {
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    if (!handle) return 1;

    const llama_vocab* vocab = handle->vocab;

    int n_prompt = -llama_tokenize(vocab, prompt, strlen(prompt), NULL, 0, true, true);
    if (n_prompt < 0) {
        MLLM_LOGE("mllm_complete_stream: tokenize failed");
        return 1;
    }

    std::vector<llama_token> prompt_tokens(n_prompt);
    if (llama_tokenize(vocab, prompt, strlen(prompt), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        MLLM_LOGE("mllm_complete_stream: tokenize failed");
        return 1;
    }

    return run_stream_loop(handle, prompt_tokens.data(), n_prompt, max_tokens, temperature, callback, user_data);
}

char* mllm_complete(void* handle_ptr,
                    const char* prompt,
                    int max_tokens,
                    float temperature) {
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    if (!handle) return NULL;

    const llama_vocab* vocab = handle->vocab;

    int n_prompt = -llama_tokenize(vocab, prompt, strlen(prompt), NULL, 0, true, true);
    if (n_prompt < 0) {
        MLLM_LOGE("mllm_complete: tokenize failed");
        return NULL;
    }

    std::vector<llama_token> prompt_tokens(n_prompt);
    if (llama_tokenize(vocab, prompt, strlen(prompt), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        MLLM_LOGE("mllm_complete: tokenize failed");
        return NULL;
    }

    return run_sample_loop(handle, prompt_tokens.data(), n_prompt, max_tokens, temperature);
}

char* mllm_multimodal_complete(void* handle_ptr,
                               const char* prompt,
                               const unsigned char* image_data,
                               size_t image_data_size,
                               int image_width,
                               int image_height,
                               int max_tokens,
                               float temperature) {
    MLLM_LOGI("mllm_multimodal_complete: called with image %dx%d, data_size=%zu", image_width, image_height, image_data_size);
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    if (!handle) {
        MLLM_LOGE("mllm_multimodal_complete: handle is null");
        return NULL;
    }
    if (!handle->mtmd_ctx) {
        MLLM_LOGW("mllm_multimodal_complete: mtmd not initialized, falling back to text-only");
        return mllm_complete(handle_ptr, prompt, max_tokens, temperature);
    }

    MLLM_LOGI("mllm_multimodal_complete: creating bitmap...");
    mtmd_bitmap* bitmap = mtmd_bitmap_init(image_width, image_height, image_data);
    if (!bitmap) {
        MLLM_LOGE("mllm_multimodal_complete: failed to create bitmap");
        return NULL;
    }
    MLLM_LOGI("mllm_multimodal_complete: bitmap created successfully");

    std::string full_prompt = std::string(mtmd_default_marker()) + "\n" + prompt;
    mtmd_input_text input_text;
    input_text.text = full_prompt.c_str();
    input_text.add_special = true;
    input_text.parse_special = true;

    const mtmd_bitmap* bitmaps[] = { bitmap };
    mtmd_input_chunks* chunks = mtmd_input_chunks_init();

    MLLM_LOGI("mllm_multimodal_complete: tokenizing...");
    int32_t ret = mtmd_tokenize(handle->mtmd_ctx, chunks, &input_text, bitmaps, 1);
    mtmd_bitmap_free(bitmap);

    if (ret != 0) {
        MLLM_LOGE("mllm_multimodal_complete: mtmd_tokenize failed (%d)", ret);
        mtmd_input_chunks_free(chunks);
        return NULL;
    }
    MLLM_LOGI("mllm_multimodal_complete: tokenize success, chunks=%zu", mtmd_input_chunks_size(chunks));

    // encode 图片 chunk
    MLLM_LOGI("mllm_multimodal_complete: encoding chunks...");
    for (size_t i = 0; i < mtmd_input_chunks_size(chunks); i++) {
        const mtmd_input_chunk* chunk = mtmd_input_chunks_get(chunks, i);
        if (mtmd_input_chunk_get_type(chunk) != MTMD_INPUT_CHUNK_TYPE_TEXT) {
            MLLM_LOGI("mllm_multimodal_complete: encoding chunk %zu...", i);
            if (mtmd_encode_chunk(handle->mtmd_ctx, chunk) != 0) {
                MLLM_LOGE("mllm_multimodal_complete: encode_chunk failed");
                mtmd_input_chunks_free(chunks);
                return NULL;
            }
        }
    }

    // 收集所有 text token（图片 chunk 的 embedding 已注入 context）
    std::vector<llama_token> all_tokens;
    for (size_t i = 0; i < mtmd_input_chunks_size(chunks); i++) {
        const mtmd_input_chunk* chunk = mtmd_input_chunks_get(chunks, i);
        if (mtmd_input_chunk_get_type(chunk) == MTMD_INPUT_CHUNK_TYPE_TEXT) {
            size_t n_tokens = 0;
            const llama_token* tokens = mtmd_input_chunk_get_tokens_text(chunk, &n_tokens);
            if (tokens && n_tokens > 0) {
                for (size_t j = 0; j < n_tokens; j++) {
                    all_tokens.push_back(tokens[j]);
                }
            }
        }
    }

    mtmd_input_chunks_free(chunks);

    if (all_tokens.empty()) {
        MLLM_LOGE("mllm_multimodal_complete: no text tokens found");
        return NULL;
    }

    MLLM_LOGI("mllm_multimodal_complete: running inference with %zu tokens...", all_tokens.size());
    return run_sample_loop(handle, all_tokens.data(), all_tokens.size(), max_tokens, temperature);
}

void mllm_close(void* handle_ptr) {
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    if (!handle) return;

    if (handle->mtmd_ctx) mtmd_free(handle->mtmd_ctx);
    llama_sampler_free(handle->sampler);
    llama_free(handle->ctx);
    llama_model_free(handle->model);
    free(handle);
    close_log_file();
}

void mllm_free_string(char* str) {
    if (str) free(str);
}
#endif // MLLM_STUB
