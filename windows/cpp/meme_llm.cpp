#include "meme_llm.h"

#ifdef MLLM_STUB
#include <stdlib.h>
void* mllm_init(const char*, const char*, int, int, int, int, const char*, const char*) { return NULL; }
void mllm_close(void*) {}
void mllm_free_string(char*) {}
void mllm_log_to_file(int, const char*, ...) {}
char* mllm_get_logs(uint64_t, uint64_t*) { char* s = (char*)malloc(1); s[0] = '\0'; return s; }
int mllm_is_mtmd_loaded(void*) { return 0; }
char* mllm_multimodal_chat(void*, const char*, const unsigned char*, size_t, int, int, int, float) { return NULL; }
int mllm_run_diagnostics(const char*) { return 0; }
#else

#include "llama.h"
#include "mtmd.h"
#include "mtmd-helper.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>
#include <string>
#include <exception>
#include <stdarg.h>
#include <csetjmp>

#ifdef _WIN32
#include <Windows.h>
#else
#include <pthread.h>
#include <sys/time.h>
#include <signal.h>
#ifdef __ANDROID__
#include <android/log.h>
#include <dlfcn.h>
#endif
#endif

#define LOG_RING_CAPACITY 500
#define LOG_LINE_MAX 1024

static FILE* g_log_file = NULL;

#ifdef _WIN32
static CRITICAL_SECTION g_log_file_mutex;
static CRITICAL_SECTION g_log_ring_mutex;
#else
static pthread_mutex_t g_log_file_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t g_log_ring_mutex = PTHREAD_MUTEX_INITIALIZER;
#endif

static struct {
    char lines[LOG_RING_CAPACITY][LOG_LINE_MAX];
    uint64_t ids[LOG_RING_CAPACITY];
    int head;
    uint64_t next_id;
} g_log_ring = {};

static void log_ring_push(const char* line) {
#ifdef _WIN32
    EnterCriticalSection(&g_log_ring_mutex);
#else
    pthread_mutex_lock(&g_log_ring_mutex);
#endif
    int pos = g_log_ring.head;
    strncpy(g_log_ring.lines[pos], line, LOG_LINE_MAX - 1);
    g_log_ring.lines[pos][LOG_LINE_MAX - 1] = '\0';
    g_log_ring.ids[pos] = g_log_ring.next_id++;
    g_log_ring.head = (pos + 1) % LOG_RING_CAPACITY;
#ifdef _WIN32
    LeaveCriticalSection(&g_log_ring_mutex);
#else
    pthread_mutex_unlock(&g_log_ring_mutex);
#endif
}

#ifdef _WIN32
static void get_time_of_day(struct timeval* tv) {
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    uint64_t ticks = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    ticks -= 116444736000000000ULL;
    tv->tv_sec = (long)(ticks / 10000000ULL);
    tv->tv_usec = (long)((ticks % 10000000ULL) / 10ULL);
}
#endif

static char* format_log_line(int level, const char* msg) {
    const char* prefix = (level == 2) ? "E" : (level == 1) ? "W" : "I";
    struct timeval tv;
#ifdef _WIN32
    get_time_of_day(&tv);
#else
    gettimeofday(&tv, NULL);
#endif
    struct tm tm_buf;
#ifdef _WIN32
    localtime_s(&tm_buf, &tv.tv_sec);
#else
    localtime_r(&tv.tv_sec, &tm_buf);
#endif
    char ts[32];
    strftime(ts, sizeof(ts), "%H:%M:%S", &tm_buf);
    char* line = (char*)malloc(LOG_LINE_MAX);
    int n = snprintf(line, LOG_LINE_MAX, "%s %s.%03ld %s",
                     prefix, ts, (long)tv.tv_usec / 1000, msg);
    if (n < 0) { free(line); return NULL; }
    return line;
}

extern "C" void mllm_log_to_file(int level, const char* fmt, ...) {
    char msg_buf[LOG_LINE_MAX];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msg_buf, sizeof(msg_buf), fmt, ap);
    va_end(ap);
    msg_buf[LOG_LINE_MAX - 1] = '\0';

    char* line = format_log_line(level, msg_buf);
    if (line) {
        log_ring_push(line);
        free(line);
    }

    FILE* f = g_log_file;
    if (!f) return;
    const char* prefix = (level == 2) ? "E" : (level == 1) ? "W" : "I";
    struct timeval tv;
#ifdef _WIN32
    get_time_of_day(&tv);
#else
    gettimeofday(&tv, NULL);
#endif
    struct tm tm_buf;
#ifdef _WIN32
    localtime_s(&tm_buf, &tv.tv_sec);
#else
    localtime_r(&tv.tv_sec, &tm_buf);
#endif
    char ts[32];
    strftime(ts, sizeof(ts), "%H:%M:%S", &tm_buf);
#ifdef _WIN32
    EnterCriticalSection(&g_log_file_mutex);
#else
    pthread_mutex_lock(&g_log_file_mutex);
#endif
    fprintf(f, "%s %s.%03ld ", prefix, ts, (long)tv.tv_usec / 1000);
    va_list ap2;
    va_start(ap2, fmt);
    vfprintf(f, fmt, ap2);
    va_end(ap2);
    fputc('\n', f);
    fflush(f);
#ifdef _WIN32
    LeaveCriticalSection(&g_log_file_mutex);
#else
    pthread_mutex_unlock(&g_log_file_mutex);
#endif
}

extern "C" char* mllm_get_logs(uint64_t since_id, uint64_t* out_last_id) {
    size_t cap = 4096;
    size_t len = 0;
    char* buf = (char*)malloc(cap);
    buf[0] = '\0';
    uint64_t last_id = since_id;

#ifdef _WIN32
    EnterCriticalSection(&g_log_ring_mutex);
#else
    pthread_mutex_lock(&g_log_ring_mutex);
#endif
    int count = g_log_ring.next_id < (uint64_t)LOG_RING_CAPACITY
                    ? (int)g_log_ring.next_id
                    : LOG_RING_CAPACITY;
    int start = count < LOG_RING_CAPACITY ? 0 : g_log_ring.head;
    for (int i = 0; i < count; i++) {
        int pos = (start + i) % LOG_RING_CAPACITY;
        if (g_log_ring.ids[pos] <= since_id) continue;
        if (g_log_ring.ids[pos] > last_id) last_id = g_log_ring.ids[pos];
        size_t line_len = strlen(g_log_ring.lines[pos]);
        if (len + line_len + 2 > cap) {
            cap *= 2;
            buf = (char*)realloc(buf, cap);
        }
        memcpy(buf + len, g_log_ring.lines[pos], line_len);
        len += line_len;
        buf[len++] = '\n';
    }
#ifdef _WIN32
    LeaveCriticalSection(&g_log_ring_mutex);
#else
    pthread_mutex_unlock(&g_log_ring_mutex);
#endif

    buf[len] = '\0';
    if (out_last_id) *out_last_id = last_id;
    return buf;
}

static void open_log_file(const char* path) {
    if (!path) return;
    g_log_file = fopen(path, "a");
    if (g_log_file) {
        struct timeval tv;
#ifdef _WIN32
        get_time_of_day(&tv);
#else
        gettimeofday(&tv, NULL);
#endif
        fprintf(g_log_file, "=== mllm session start, path=%s, ts=%ld.%06ld ===\n",
                path, (long)tv.tv_sec, (long)tv.tv_usec);
        fflush(g_log_file);
    }
}

static void close_log_file() {
    if (!g_log_file) return;
#ifdef _WIN32
    EnterCriticalSection(&g_log_file_mutex);
#else
    pthread_mutex_lock(&g_log_file_mutex);
#endif
    fclose(g_log_file);
    g_log_file = NULL;
#ifdef _WIN32
    LeaveCriticalSection(&g_log_file_mutex);
#else
    pthread_mutex_unlock(&g_log_file_mutex);
#endif
}

static const char* const k_llama_log_blacklist[] = {
    "llama_model_loader",
    "load_tensors",
    "create_tensor",
};
static bool llama_log_is_filtered(const char* text) {
    if (!text) return true;
    for (const char* needle : k_llama_log_blacklist) {
        if (strstr(text, needle) != NULL) return true;
    }
    return false;
}

static void llama_log_callback(enum ggml_log_level level, const char* text, void*) {
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
    int n_batch;
} MllmHandle;

extern "C" int mllm_is_mtmd_loaded(void* handle_ptr) {
    if (!handle_ptr) return 0;
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    return handle->mtmd_ctx != NULL ? 1 : 0;
}

struct ExtraParams {
    int flash_attn = -1;
    ggml_type kv_cache = GGML_TYPE_F16;
    int use_mmap = 1;
    int n_batch = 512;
    int n_ubatch = 256;
};

static ExtraParams parse_extra_params(const char* extra_params) {
    ExtraParams p;
    if (!extra_params) return p;

    char* buf = strdup(extra_params);
    if (!buf) return p;

    const char* delim = ",";
    char* token = strtok(buf, delim);
    while (token) {
        while (*token == ' ' || *token == '\t') token++;
        const char* eq = strchr(token, '=');
        if (!eq) { token = strtok(NULL, delim); continue; }

        size_t key_len = eq - token;
        const char* val = eq + 1;

        if (strncmp(token, "flash_attn", key_len) == 0 && key_len == 10) {
            if (strcmp(val, "enabled") == 0) p.flash_attn = 1;
            else if (strcmp(val, "disabled") == 0) p.flash_attn = 0;
        } else if (strncmp(token, "kv_cache", key_len) == 0 && key_len == 8) {
            if (strcmp(val, "q4_0") == 0) p.kv_cache = GGML_TYPE_Q4_0;
        } else if (strncmp(token, "use_mmap", key_len) == 0 && key_len == 8) {
            p.use_mmap = atoi(val);
        } else if (strncmp(token, "n_batch", key_len) == 0 && key_len == 7) {
            int v = atoi(val);
            if (v > 0) p.n_batch = v;
        } else if (strncmp(token, "n_ubatch", key_len) == 0 && key_len == 8) {
            int v = atoi(val);
            if (v > 0) p.n_ubatch = v;
        }

        token = strtok(NULL, delim);
    }
    free(buf);
    return p;
}

#ifdef _WIN32
static volatile long g_gpu_crashed = 0;
static jmp_buf g_gpu_jmp_buf;

static void gpu_crash_handler(int) {
    g_gpu_crashed = 1;
    longjmp(g_gpu_jmp_buf, 1);
}

static llama_model* safe_llama_model_load(const char* path, llama_model_params params) {
    g_gpu_crashed = 0;
    llama_model* model = NULL;

    if (setjmp(g_gpu_jmp_buf) == 0) {
        model = llama_model_load_from_file(path, params);
    } else {
        g_gpu_crashed = 1;
    }

    return g_gpu_crashed ? NULL : model;
}
#else
static sigjmp_buf g_gpu_jmp_buf;
static volatile sig_atomic_t g_gpu_crashed = 0;

static void gpu_crash_signal_handler(int) {
    g_gpu_crashed = 1;
    siglongjmp(g_gpu_jmp_buf, 1);
}

static llama_model* safe_llama_model_load(const char* path, llama_model_params params) {
    struct sigaction sa_segv, sa_abrt, old_segv, old_abrt;

    memset(&sa_segv, 0, sizeof(sa_segv));
    sa_segv.sa_handler = gpu_crash_signal_handler;
    sigemptyset(&sa_segv.sa_mask);
    sigaction(SIGSEGV, &sa_segv, &old_segv);

    memset(&sa_abrt, 0, sizeof(sa_abrt));
    sa_abrt.sa_handler = gpu_crash_signal_handler;
    sigemptyset(&sa_abrt.sa_mask);
    sigaction(SIGABRT, &sa_abrt, &old_abrt);

    g_gpu_crashed = 0;
    llama_model* model = NULL;
    if (sigsetjmp(g_gpu_jmp_buf, 1) == 0) {
        model = llama_model_load_from_file(path, params);
    } else {
        g_gpu_crashed = 1;
    }

    sigaction(SIGSEGV, &old_segv, NULL);
    sigaction(SIGABRT, &old_abrt, NULL);
    return g_gpu_crashed ? NULL : model;
}
#endif

void* mllm_init(const char* model_path,
                const char* mmproj_path,
                int n_threads,
                int n_ctx,
                int use_gpu,
                int n_gpu_layers,
                const char* log_file_path,
                const char* extra_params) {
#ifdef _WIN32
    InitializeCriticalSection(&g_log_file_mutex);
    InitializeCriticalSection(&g_log_ring_mutex);
#endif

    open_log_file(log_file_path);

    ExtraParams opt = parse_extra_params(extra_params);

    llama_log_set(llama_log_callback, NULL);
    ggml_log_set(llama_log_callback, NULL);

    MLLM_LOGI("mllm_init: model_path=%s, threads=%d, ctx=%d, use_gpu=%d, n_gpu_layers=%d",
              model_path, n_threads, n_ctx, use_gpu, n_gpu_layers);
    MLLM_LOGI("mllm_init: extra_params: flash_attn=%d, kv_cache=%s, use_mmap=%d, n_batch=%d, n_ubatch=%d",
              opt.flash_attn,
              opt.kv_cache == GGML_TYPE_Q4_0 ? "q4_0" : "f16",
              opt.use_mmap, opt.n_batch, opt.n_ubatch);

    llama_model_params model_params = llama_model_default_params();
    model_params.use_mmap = opt.use_mmap;
    bool should_use_gpu = false;
    llama_model* model = NULL;

    if (use_gpu) {
        ggml_backend_load_all();

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
                ggml_backend_dev_props props;
                ggml_backend_dev_get_props(dev, &props);
                MLLM_LOGI("      type=%d, async=%d, host_buf=%d, mem_free=%zu MB, mem_total=%zu MB",
                          (int)props.type, (int)props.caps.async, (int)props.caps.host_buffer,
                          props.memory_free / (1024*1024), props.memory_total / (1024*1024));
            }
        }

        int n_gpu_devices = 0;
        for (int i = 0; i < n_backends; i++) {
            ggml_backend_reg_t reg = ggml_backend_reg_get(i);
            const char* reg_name = ggml_backend_reg_name(reg);
            if (reg_name && strcmp(reg_name, "CPU") != 0 && strcmp(reg_name, "BLAS") != 0) {
                n_gpu_devices += (int)ggml_backend_reg_dev_count(reg);
            }
        }
        MLLM_LOGI("mllm_init: 检测到 GPU 设备数=%d (总设备数=%d)", n_gpu_devices, n_devices);

        if (n_gpu_devices == 0) {
            MLLM_LOGW("mllm_init: 请求 GPU 加速但未检测到 GPU 设备");
            MLLM_LOGW("mllm_init: 可能原因: 1) 设备不支持 2) llama.cpp 未编译 GPU 后端 3) 驱动问题");
        }

        should_use_gpu = (n_gpu_devices > 0);
        if (should_use_gpu) {
            model_params.n_gpu_layers = n_gpu_layers;
            MLLM_LOGI("mllm_init: GPU 加速已启用, n_gpu_layers=%d", n_gpu_layers);
        } else {
            MLLM_LOGW("mllm_init: 请求 GPU 加速但未检测到 GPU 设备，回退到 CPU");
            model_params.n_gpu_layers = 0;
        }

        MLLM_LOGI("mllm_init: 开始模型加载（GPU 模式）...");
        model = safe_llama_model_load(model_path, model_params);
        if (g_gpu_crashed) {
            MLLM_LOGW("mllm_init: GPU 模式加载触发崩溃，回退到 CPU 重试");
            model_params.n_gpu_layers = 0;
            model_params.split_mode = LLAMA_SPLIT_MODE_NONE;
            model_params.main_gpu = -1;
            should_use_gpu = false;
            model = safe_llama_model_load(model_path, model_params);
            if (g_gpu_crashed) {
                MLLM_LOGE("mllm_init: CPU 模式加载也崩溃，不可恢复");
                return NULL;
            }
        }
    } else {
        MLLM_LOGI("mllm_init: 开始模型加载（CPU 模式）...");
        model_params.n_gpu_layers = 0;
        model_params.split_mode = LLAMA_SPLIT_MODE_NONE;
        model_params.main_gpu = -1;
        model = llama_model_load_from_file(model_path, model_params);
    }

    if (!model) {
        MLLM_LOGE("mllm_init: failed to load model from %s", model_path);
        return NULL;
    }

    const llama_vocab* vocab = llama_model_get_vocab(model);

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx   = n_ctx;
    ctx_params.n_batch = opt.n_batch;
    ctx_params.n_ubatch = opt.n_ubatch;
    ctx_params.type_k = opt.kv_cache;
    ctx_params.type_v = opt.kv_cache;
    ctx_params.flash_attn_type = (opt.flash_attn == -1)
        ? LLAMA_FLASH_ATTN_TYPE_AUTO
        : (opt.flash_attn ? LLAMA_FLASH_ATTN_TYPE_ENABLED : LLAMA_FLASH_ATTN_TYPE_DISABLED);
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;

    MLLM_LOGI("mllm_init: 开始 llama_init_from_model...");
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
    if (mmproj_path && mmproj_path[0] != '\0') {
        MLLM_LOGI("mllm_init: loading mtmd from '%s'", mmproj_path);
        auto mtmd_params = mtmd_context_params_default();
        mtmd_params.use_gpu = should_use_gpu;
        mtmd_params.n_threads = n_threads;
        MLLM_LOGI("mllm_init: mtmd_params.use_gpu=%d, 开始 mtmd_init_from_file...", mtmd_params.use_gpu);
        mtmd_ctx = mtmd_init_from_file(mmproj_path, model, mtmd_params);
        if (!mtmd_ctx) {
            MLLM_LOGE("mllm_init: failed to init mtmd from %s", mmproj_path);
            llama_sampler_free(sampler);
            llama_free(ctx);
            llama_model_free(model);
            return NULL;
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
    handle->n_batch = opt.n_batch;
    return handle;
}

extern "C" char* mllm_multimodal_chat(void* handle_ptr,
                                       const char* messages_json,
                                       const unsigned char* image_data,
                                       size_t image_data_size,
                                       int image_width,
                                       int image_height,
                                       int max_tokens,
                                       float temperature) {
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    if (!handle) return NULL;
    if (!handle->mtmd_ctx) {
        MLLM_LOGE("mllm_multimodal_chat: mtmd not initialized");
        return NULL;
    }

    MLLM_LOGI("mllm_multimodal_chat: called with image %dx%d, data_size=%zu",
              image_width, image_height, image_data_size);

    std::vector<std::string> role_strs;
    std::vector<std::string> content_strs;

    const char* p = messages_json;
    while (*p && (*p == ' ' || *p == '\n' || *p == '[')) p++;
    if (*p != '{') {
        MLLM_LOGE("mllm_multimodal_chat: invalid JSON format");
        return NULL;
    }

    while (*p && *p != ']') {
        while (*p && (*p == ' ' || *p == '\n' || *p == ',')) p++;
        if (*p != '{') break;

        std::string role_val, content_val;
        p++;

        for (int field = 0; field < 2; field++) {
            while (*p && (*p == ' ' || *p == '\n')) p++;
            const char* key_start = p;
            while (*p && *p != ':') p++;
            if (*p != ':') { p++; continue; }
            std::string key(key_start, p - key_start);
            p++;

            while (*p && (*p == ' ' || *p == '"')) p++;
            std::string val;
            while (*p && *p != '"') {
                if (*p == '\\' && *(p+1)) {
                    val.push_back(*p);
                    p++;
                    val.push_back(*p);
                    p++;
                } else {
                    val.push_back(*p);
                    p++;
                }
            }
            p++;

            if (key.find("role") != std::string::npos) {
                role_val = val;
            } else if (key.find("content") != std::string::npos) {
                content_val = val;
            }
        }

        if (!role_val.empty() && !content_val.empty()) {
            role_strs.push_back(role_val);
            content_strs.push_back(content_val);
        }

        while (*p && (*p == ' ' || *p == '\n' || *p == '}' || *p == ',')) p++;
    }

    if (role_strs.empty()) {
        MLLM_LOGE("mllm_multimodal_chat: no valid messages found");
        return NULL;
    }

    const char* tmpl = llama_model_chat_template(handle->model, NULL);
    if (!tmpl) {
        MLLM_LOGE("mllm_multimodal_chat: model has no chat template");
        return NULL;
    }

    std::vector<llama_chat_message> chat_msgs(role_strs.size());
    for (size_t i = 0; i < role_strs.size(); i++) {
        chat_msgs[i].role = role_strs[i].c_str();
        chat_msgs[i].content = content_strs[i].c_str();
    }

    size_t buf_size = 4096;
    std::vector<char> buf(buf_size);
    int32_t len = llama_chat_apply_template(
        tmpl, chat_msgs.data(), chat_msgs.size(), true, buf.data(), buf_size);
    if (len < 0) {
        MLLM_LOGE("mllm_multimodal_chat: llama_chat_apply_template failed");
        return NULL;
    }
    if ((size_t)len > buf_size) {
        buf.resize(len + 1);
        len = llama_chat_apply_template(
            tmpl, chat_msgs.data(), chat_msgs.size(), true, buf.data(), len + 1);
        if (len < 0) {
            MLLM_LOGE("mllm_multimodal_chat: llama_chat_apply_template failed on retry");
            return NULL;
        }
    }
    std::string formatted_prompt(buf.data(), len);
    MLLM_LOGI("mllm_multimodal_chat: formatted prompt (%d chars), contains marker: %s",
              (int)formatted_prompt.size(),
              formatted_prompt.find(mtmd_default_marker()) != std::string::npos ? "YES" : "NO (!!!)");

    mtmd_bitmap* bitmap = mtmd_bitmap_init(image_width, image_height, image_data);
    if (!bitmap) {
        MLLM_LOGE("mllm_multimodal_chat: failed to create bitmap");
        return NULL;
    }

    mtmd_input_text input_text;
    input_text.text = formatted_prompt.c_str();
    input_text.add_special = true;
    input_text.parse_special = true;

    const mtmd_bitmap* bitmaps[] = { bitmap };
    mtmd_input_chunks* chunks = mtmd_input_chunks_init();

    MLLM_LOGI("mllm_multimodal_chat: tokenizing with bitmap...");
    int32_t ret = mtmd_tokenize(handle->mtmd_ctx, chunks, &input_text, bitmaps, 1);
    mtmd_bitmap_free(bitmap);

    if (ret != 0) {
        MLLM_LOGE("mllm_multimodal_chat: mtmd_tokenize failed (%d)", ret);
        mtmd_input_chunks_free(chunks);
        return NULL;
    }
    MLLM_LOGI("mllm_multimodal_chat: tokenize success, chunks=%zu",
              mtmd_input_chunks_size(chunks));

    if (temperature > 0.0f) {
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    } else {
        llama_sampler_chain_add(handle->sampler, llama_sampler_init_greedy());
    }

    llama_memory_clear(llama_get_memory(handle->ctx), true);

    llama_pos n_past = 0;
    MLLM_LOGI("mllm_multimodal_chat: evaluating chunks with mtmd_helper_eval_chunks...");
    int32_t eval_ret = mtmd_helper_eval_chunks(
        handle->mtmd_ctx,
        handle->ctx,
        chunks,
        n_past,
        0,
        handle->n_batch,
        true,
        &n_past
    );

    mtmd_input_chunks_free(chunks);

    if (eval_ret != 0) {
        MLLM_LOGE("mllm_multimodal_chat: mtmd_helper_eval_chunks failed (%d)", eval_ret);
        while (llama_sampler_chain_n(handle->sampler) > 2) {
            llama_sampler* removed = llama_sampler_chain_remove(
                handle->sampler, llama_sampler_chain_n(handle->sampler) - 1);
            llama_sampler_free(removed);
        }
        return NULL;
    }

    MLLM_LOGI("mllm_multimodal_chat: prompt eval done, n_past=%d, starting generation (max %d tokens)...",
              n_past, max_tokens);

    std::string result;
    for (int i = 0; i < max_tokens; i++) {
        llama_token new_token = llama_sampler_sample(handle->sampler, handle->ctx, -1);
        llama_sampler_accept(handle->sampler, new_token);

        if (llama_vocab_is_eog(handle->vocab, new_token)) {
            MLLM_LOGI("mllm_multimodal_chat: EOS token %d generated", new_token);
            break;
        }

        char buf_piece[256];
        int n = llama_token_to_piece(handle->vocab, new_token, buf_piece, sizeof(buf_piece), 0, true);
        if (n > 0) {
            result.append(buf_piece, n);
        }

        llama_batch token_batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(handle->ctx, token_batch)) {
            MLLM_LOGE("mllm_multimodal_chat: llama_decode failed at step %d", i);
            break;
        }
    }

    while (llama_sampler_chain_n(handle->sampler) > 2) {
        llama_sampler* removed = llama_sampler_chain_remove(
            handle->sampler, llama_sampler_chain_n(handle->sampler) - 1);
        llama_sampler_free(removed);
    }

    MLLM_LOGI("mllm_multimodal_chat: generated %zu chars", result.size());
    if (result.size() > 0) {
        MLLM_LOGI("mllm_multimodal_chat: result preview: %.*s",
                  (int)std::min(result.size(), (size_t)200), result.c_str());
    }

    char* ret_str = (char*)malloc(result.size() + 1);
    if (ret_str) {
        memcpy(ret_str, result.c_str(), result.size());
        ret_str[result.size()] = '\0';
    }
    return ret_str;
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

int mllm_run_diagnostics(const char* log_file_path) {
    open_log_file(log_file_path);

    MLLM_LOGI("=== mllm_run_diagnostics BEGIN ===");

    MLLM_LOGI("[diagnostic] 步骤 1: ggml_backend_load_all()");
    ggml_backend_load_all();

    int n_backends = (int)ggml_backend_reg_count();
    int n_devices = (int)ggml_backend_dev_count();
    MLLM_LOGI("[diagnostic] 步骤 2: 发现 %d 个后端, %d 个设备", n_backends, n_devices);

    int n_gpu = 0;
    for (int i = 0; i < n_backends; i++) {
        ggml_backend_reg_t reg = ggml_backend_reg_get(i);
        const char* reg_name = ggml_backend_reg_name(reg);
        size_t n_reg_dev = ggml_backend_reg_dev_count(reg);
        MLLM_LOGI("[diagnostic]   backend[%d]: \"%s\" (%zu devices)", i, reg_name ? reg_name : "?", n_reg_dev);

        for (size_t j = 0; j < n_reg_dev; j++) {
            ggml_backend_dev_t dev = ggml_backend_reg_dev_get(reg, j);
            const char* dev_name = ggml_backend_dev_name(dev);
            const char* dev_desc = ggml_backend_dev_description(dev);
            MLLM_LOGI("[diagnostic]     device[%zu]: \"%s\" — %s", j,
                      dev_name ? dev_name : "?", dev_desc ? dev_desc : "?");
            if (reg_name && strcmp(reg_name, "CPU") != 0 && strcmp(reg_name, "BLAS") != 0) {
                n_gpu++;
            }
        }
    }

    MLLM_LOGI("[diagnostic] 步骤 3: 检测到 GPU 设备数=%d (总设备数=%d)", n_gpu, n_devices);
    MLLM_LOGI("[diagnostic]   (Windows 平台，跳过 dlopen 测试)");
    MLLM_LOGI("=== mllm_run_diagnostics END ===");
    close_log_file();
    return 0;
}
#endif
