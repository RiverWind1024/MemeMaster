#ifndef MEME_LLM_H
#define MEME_LLM_H

#include <stddef.h>
#include <stdint.h>

// ---- Android 日志宏 ----
// fprintf(stderr, ...) 在 Android NDK 上不一定进入 logcat，
// 改用 __android_log_print 确保日志可见。
// 同时把日志写入指定文件，方便在 app 内的 LogViewer 显示。
#ifdef __cplusplus
extern "C" {
#endif
#ifdef __ANDROID__
#include <android/log.h>
#define MLLM_LOG_TAG "meme_llm"
void mllm_log_to_file(int level, const char* fmt, ...);
#define MLLM_LOGI(...) do { __android_log_print(ANDROID_LOG_INFO,  MLLM_LOG_TAG, __VA_ARGS__); mllm_log_to_file(0, __VA_ARGS__); } while (0)
#define MLLM_LOGW(...) do { __android_log_print(ANDROID_LOG_WARN,  MLLM_LOG_TAG, __VA_ARGS__); mllm_log_to_file(1, __VA_ARGS__); } while (0)
#define MLLM_LOGE(...) do { __android_log_print(ANDROID_LOG_ERROR, MLLM_LOG_TAG, __VA_ARGS__); mllm_log_to_file(2, __VA_ARGS__); } while (0)
#else
#include <stdio.h>
#define MLLM_LOGI(...) fprintf(stderr, __VA_ARGS__)
#define MLLM_LOGW(...) fprintf(stderr, __VA_ARGS__)
#define MLLM_LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif
#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
extern "C" {
#endif

// 初始化：加载模型 + 可选 mmproj
// use_gpu: 0=CPU only, 1=尝试 GPU 加速
// n_gpu_layers: 卸载到 GPU 的层数（use_gpu=1 时有效，-1=全部）
// log_file_path: 把 C++ 端日志同时写入此文件（可为 NULL 表示只写 logcat）
// 返回 opaque handle，失败返回 NULL
void* mllm_init(const char* model_path,
                const char* mmproj_path,
                int n_threads,
                int n_ctx,
                int use_gpu,
                int n_gpu_layers,
                const char* log_file_path);

// 纯文本补全
// 返回生成的文本（调用方须 mllm_free_string 释放），失败返回 NULL
char* mllm_complete(void* handle,
                    const char* prompt,
                    int max_tokens,
                    float temperature);

// 多模态补全（文本 + 图片）
// image_data: RGB 像素数据; image_data_size: 数据字节数
// image_width/height: 图片尺寸
// 返回生成的文本（调用方须 mllm_free_string 释放），失败返回 NULL
char* mllm_multimodal_complete(void* handle,
                               const char* prompt,
                               const unsigned char* image_data,
                               size_t image_data_size,
                               int image_width,
                               int image_height,
                               int max_tokens,
                               float temperature);

// 释放资源
void mllm_close(void* handle);

// 释放 mllm_complete / mllm_multimodal_complete 返回的字符串
void mllm_free_string(char* str);

// ---- Streaming API ----

// 逐 token 回调：每次生成一个 token piece 时调用
// 返回 0 继续生成，非 0 中止
typedef int (*mllm_token_callback_t)(const char* token_text, void* user_data);

// 流式文本补全 — 每生成一个 token 就回调一次
// 返回 0 成功，非 0 失败或被回调中止
int mllm_complete_stream(void* handle,
                         const char* prompt,
                         int max_tokens,
                         float temperature,
                         mllm_token_callback_t callback,
                         void* user_data);

#ifdef __cplusplus
}
#endif

#endif // MEME_LLM_H
