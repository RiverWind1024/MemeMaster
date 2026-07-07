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
// extra_params: 额外优化参数，格式 "key=val,key=val,..." 或 NULL
//   支持的 key:
//     flash_attn   = auto | enabled | disabled  （默认 auto）
//     kv_cache     = f16 | q4_0                 （默认 f16）
//     kv_unified   = 1 | 0                      （默认 1）
//     use_mmap     = 1 | 0                      （默认 0，Android 推荐关闭）
//     n_batch      = <数值>                      （默认 512）
//     n_ubatch     = <数值>                      （默认 256）
// 返回 opaque handle，失败返回 NULL
void* mllm_init(const char* model_path,
                const char* mmproj_path,
                int n_threads,
                int n_ctx,
                int use_gpu,
                int n_gpu_layers,
                const char* log_file_path,
                const char* extra_params);

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

// 多模态对话（使用 chat template）
// messages_json: JSON 格式的消息数组，含图片的消息 content 须包含 <__media__> 标记
//   如 [{"role":"user","content":"<__media__>\n请分析这张图片"}]
// image_data: RGB 像素数据（width*height*3 字节）
// 返回生成的文本（调用方须 mllm_free_string 释放），失败返回 NULL
char* mllm_multimodal_chat(void* handle,
                           const char* messages_json,
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

// 获取 C++ 侧捕获的最近日志
// 返回日志文本（以 \0 结尾的 UTF-8 字符串），调用方须 mllm_free_string 释放
// 每次调用返回上次调用之后新增的日志行；首次调用 / since_id=0 返回全部
// since_id: 传入上次调用返回的 last_id，增量获取；首次传 0
// out_last_id: 输出本次返回的最后一条日志的 ID，供下次调用传入
char* mllm_get_logs(uint64_t since_id, uint64_t* out_last_id);

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
