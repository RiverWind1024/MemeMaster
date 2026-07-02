#include "meme_llm.h"

#ifdef MLLM_STUB
void* mllm_init(const char*, const char*, int, int) { return NULL; }
char* mllm_complete(void*, const char*, int, float) { return NULL; }
char* mllm_multimodal_complete(void*, const char*, const unsigned char*, size_t, int, int, int, float) { return NULL; }
void mllm_close(void*) {}
void mllm_free_string(char*) {}
#else

#include "llama.h"
#include "mtmd.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>
#include <string>

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
                int n_ctx) {
    ggml_backend_load_all();

    llama_model_params model_params = llama_model_default_params();
    llama_model* model = llama_model_load_from_file(model_path, model_params);
    if (!model) {
        fprintf(stderr, "mllm_init: failed to load model from %s\n", model_path);
        return NULL;
    }

    const llama_vocab* vocab = llama_model_get_vocab(model);

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx   = n_ctx;
    ctx_params.n_batch = n_ctx;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;

    llama_context* ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        fprintf(stderr, "mllm_init: failed to create context\n");
        llama_model_free(model);
        return NULL;
    }

    auto sparams = llama_sampler_chain_default_params();
    llama_sampler* sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.0f));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    mtmd_context* mtmd_ctx = NULL;
    if (mmproj_path) {
        auto mtmd_params = mtmd_context_params_default();
        mtmd_params.use_gpu = false;
        mtmd_params.n_threads = n_threads;
        mtmd_ctx = mtmd_init_from_file(mmproj_path, model, mtmd_params);
        if (!mtmd_ctx) {
            fprintf(stderr, "mllm_init: failed to init mtmd from %s (non-fatal)\n", mmproj_path);
        }
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
            fprintf(stderr, "run_sample_loop: llama_decode failed\n");
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

    llama_batch_free(batch);

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

char* mllm_complete(void* handle_ptr,
                    const char* prompt,
                    int max_tokens,
                    float temperature) {
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    if (!handle) return NULL;

    const llama_vocab* vocab = handle->vocab;

    int n_prompt = -llama_tokenize(vocab, prompt, strlen(prompt), NULL, 0, true, true);
    if (n_prompt < 0) {
        fprintf(stderr, "mllm_complete: tokenize failed\n");
        return NULL;
    }

    std::vector<llama_token> prompt_tokens(n_prompt);
    if (llama_tokenize(vocab, prompt, strlen(prompt), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        fprintf(stderr, "mllm_complete: tokenize failed\n");
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
    MllmHandle* handle = (MllmHandle*)handle_ptr;
    if (!handle) return NULL;
    if (!handle->mtmd_ctx) {
        fprintf(stderr, "mllm_multimodal_complete: mtmd not initialized, falling back to text-only\n");
        return mllm_complete(handle_ptr, prompt, max_tokens, temperature);
    }

    mtmd_bitmap* bitmap = mtmd_bitmap_init(image_width, image_height, image_data);
    if (!bitmap) {
        fprintf(stderr, "mllm_multimodal_complete: failed to create bitmap\n");
        return NULL;
    }

    std::string full_prompt = std::string(mtmd_default_marker()) + "\n" + prompt;
    mtmd_input_text input_text;
    input_text.text = full_prompt.c_str();
    input_text.add_special = true;
    input_text.parse_special = true;

    const mtmd_bitmap* bitmaps[] = { bitmap };
    mtmd_input_chunks* chunks = mtmd_input_chunks_init();

    int32_t ret = mtmd_tokenize(handle->mtmd_ctx, chunks, &input_text, bitmaps, 1);
    mtmd_bitmap_free(bitmap);

    if (ret != 0) {
        fprintf(stderr, "mllm_multimodal_complete: mtmd_tokenize failed (%d)\n", ret);
        mtmd_input_chunks_free(chunks);
        return NULL;
    }

    // encode 图片 chunk
    for (size_t i = 0; i < mtmd_input_chunks_size(chunks); i++) {
        const mtmd_input_chunk* chunk = mtmd_input_chunks_get(chunks, i);
        if (mtmd_input_chunk_get_type(chunk) != MTMD_INPUT_CHUNK_TYPE_TEXT) {
            if (mtmd_encode_chunk(handle->mtmd_ctx, chunk) != 0) {
                fprintf(stderr, "mllm_multimodal_complete: encode_chunk failed\n");
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
            for (size_t j = 0; j < n_tokens; j++) {
                all_tokens.push_back(tokens[j]);
            }
        }
    }

    mtmd_input_chunks_free(chunks);

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
}

void mllm_free_string(char* str) {
    if (str) free(str);
}
#endif // MLLM_STUB
