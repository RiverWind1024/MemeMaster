#ifndef MEME_LLM_H
#define MEME_LLM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 初始化：加载模型 + 可选 mmproj
// 返回 opaque handle，失败返回 NULL
void* mllm_init(const char* model_path,
                const char* mmproj_path,
                int n_threads,
                int n_ctx);

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

#ifdef __cplusplus
}
#endif

#endif // MEME_LLM_H
