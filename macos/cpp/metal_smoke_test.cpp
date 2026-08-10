// macOS Metal 冒烟测试工具：复现并定位 MemeMaster 本地 LLM 推理崩溃
//
// 设计要点：
// 1. 链接真实的 libmeme_llm.dylib，调用与生产代码完全相同的
//    mllm_run_diagnostics / mllm_init / mllm_multimodal_chat。
// 2. 默认在独立 pthread 工作线程中执行（模拟 Dart FFI isolate 后台线程场景，
//    与真实 app 中 mllm_init/decode 所在线程一致），可通过 --no-worker 用主线程。
// 3. 安装 SIGSEGV/SIGABRT/SIGBUS 处理器，崩溃时把 backtrace 写入崩溃文件，
//    确保 CI 能拿到崩溃现场（而不是进程静默消失）。
// 4. 通过命令行参数覆盖 extra_params，用于逐项对照实验（flash_attn / kv_cache 等）。
//
// 用法:
//   metal_smoke_test --model <gguf> --mmproj <gguf> [options]
//   options:
//     --gpu 0|1           是否请求 GPU（默认 1）
//     --layers N          n_gpu_layers（默认 99）
//     --ctx N             上下文长度（默认 2048）
//     --threads N         推理线程数（默认 4）
//     --flash-attn auto|enabled|disabled（默认 auto）
//     --kv-cache f16|q4_0（默认 f16）
//     --mmap 0|1          use_mmap（默认 1）
//     --batch N / --ubatch N（默认 512 / 256）
//     --max-tokens N      推理最大 token 数（默认 32）
//     --no-infer          只加载模型 + 创建 context，不做推理
//     --no-worker         在 main 线程执行（默认独立 pthread）
//     --case NAME         用例名，写进 [RESULT]/崩溃文件（默认 "unknown"）
//     --crash-file PATH   崩溃报告输出路径（默认 不写文件，仅 stderr）
//     --log FILE          mllm 日志文件路径（透传 mllm_init）

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#include <execinfo.h>
#include <fcntl.h>
#include <sys/stat.h>

#include "meme_llm.h"

namespace {

// ---- 全局参数 ----
const char* g_model = nullptr;
const char* g_mmproj = nullptr;
int g_gpu = 1;
int g_layers = 99;
int g_ctx = 2048;
int g_threads = 4;
std::string g_flash_attn = "auto";
std::string g_kv_cache = "f16";
int g_mmap = 1;
int g_batch = 512;
int g_ubatch = 256;
int g_max_tokens = 32;
bool g_no_infer = false;
bool g_no_worker = false;
std::string g_case = "unknown";
std::string g_crash_file;
std::string g_log_file;

// 崩溃现场标记
volatile sig_atomic_t g_crashed = 0;

// ---- 崩溃处理器：打印 backtrace 到 stderr + 崩溃文件 ----
void crash_handler(int sig) {
    g_crashed = 1;
    char msg[512];
    int n = snprintf(msg, sizeof(msg),
                     "\n=== CRASH signal=%d case=%s thread=%lx ===\n",
                     sig, g_case.c_str(), (unsigned long)pthread_self());
    if (n > 0) {
        write(STDERR_FILENO, msg, (size_t)n);
        if (!g_crash_file.empty()) {
            int fd = open(g_crash_file.c_str(), O_WRONLY | O_CREAT | O_APPEND, 0644);
            if (fd >= 0) {
                write(fd, msg, (size_t)n);
                close(fd);
            }
        }
    }

    // backtrace_symbols_fd 不是 async-signal-safe 的，但实践中用于崩溃报告足够，
    // 这是诊断工具的已知取舍。
    void* frames[64];
    int count = backtrace(frames, 64);
    backtrace_symbols_fd(frames, count, STDERR_FILENO);
    _exit(2);
}

void install_crash_handlers() {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = crash_handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, nullptr);
    sigaction(SIGABRT, &sa, nullptr);
    sigaction(SIGBUS, &sa, nullptr);
}

// 生成 64x64 RGB 渐变测试图
std::vector<unsigned char> make_test_image(int w, int h) {
    std::vector<unsigned char> rgb((size_t)w * h * 3);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            size_t i = (size_t)(y * w + x) * 3;
            rgb[i]     = (unsigned char)(x * 255 / (w > 1 ? w - 1 : 1));
            rgb[i + 1] = (unsigned char)(y * 255 / (h > 1 ? h - 1 : 1));
            rgb[i + 2] = (unsigned char)((x + y) * 255 / (w + h > 2 ? w + h - 2 : 1));
        }
    }
    return rgb;
}

void print_result(const char* status) {
    printf("[RESULT] %s %s\n", g_case.c_str(), status);
    fflush(stdout);
}

// ---- 工作线程入口（模拟 Dart FFI isolate 后台线程）----
void* worker_main(void*) {
    install_crash_handlers();

    // Phase 0: 后端诊断（枚举 Metal/CPU 设备）
    printf("[phase] %s diag: mllm_run_diagnostics(log=%s)\n",
           g_case.c_str(), g_log_file.c_str());
    fflush(stdout);
    int diag_rc = mllm_run_diagnostics(g_log_file.empty() ? nullptr : g_log_file.c_str());
    printf("[phase] %s diag: rc=%d\n", g_case.c_str(), diag_rc);
    fflush(stdout);

    // Phase 1: 初始化（与 app 相同的参数透传）
    std::string extra = "flash_attn=" + g_flash_attn +
                        ",kv_cache=" + g_kv_cache +
                        ",use_mmap=" + std::to_string(g_mmap) +
                        ",n_batch=" + std::to_string(g_batch) +
                        ",n_ubatch=" + std::to_string(g_ubatch);
    printf("[phase] %s init: model=%s mmproj=%s threads=%d ctx=%d gpu=%d layers=%d extra=[%s]\n",
           g_case.c_str(), g_model, g_mmproj ? g_mmproj : "(none)",
           g_threads, g_ctx, g_gpu, g_layers, extra.c_str());
    fflush(stdout);

    void* handle = mllm_init(g_model, g_mmproj, g_threads, g_ctx, g_gpu, g_layers,
                             g_log_file.empty() ? nullptr : g_log_file.c_str(),
                             extra.c_str());
    if (!handle) {
        print_result("init-failed");
        return nullptr;
    }
    printf("[phase] %s init: ok handle=%p\n", g_case.c_str(), handle);
    fflush(stdout);

    if (g_no_infer) {
        mllm_close(handle);
        print_result("pass(no-infer)");
        return nullptr;
    }

    // Phase 2: 多模态推理（真实解码，Metal kernel 在此执行）
    const int img_w = 64, img_h = 64;
    auto image = make_test_image(img_w, img_h);
    const char* messages =
        "[{\"role\":\"user\",\"content\":\"<__media__>\\ndescribe this image briefly\"}]";
    printf("[phase] %s infer: image=%dx%d max_tokens=%d ...\n",
           g_case.c_str(), img_w, img_h, g_max_tokens);
    fflush(stdout);

    char* out = mllm_multimodal_chat(handle, messages, image.data(), image.size(),
                                     img_w, img_h, g_max_tokens, 0.0f);
    if (!out) {
        print_result("infer-null");
        mllm_close(handle);
        return nullptr;
    }
    printf("[phase] %s infer: output (%zu chars): %.*s\n", g_case.c_str(),
           strlen(out), (int)(strlen(out) > 200 ? 200 : strlen(out)), out);
    mllm_free_string(out);
    mllm_close(handle);
    print_result("pass");
    return nullptr;
}

// ---- 参数解析 ----
bool parse_args(int argc, char** argv) {
    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        auto next = [&](const char* name) -> const char* {
            if (i + 1 >= argc) {
                fprintf(stderr, "missing value for %s\n", name);
                exit(2);
            }
            return argv[++i];
        };
        if (a == "--model") g_model = next("--model");
        else if (a == "--mmproj") g_mmproj = next("--mmproj");
        else if (a == "--gpu") g_gpu = atoi(next("--gpu"));
        else if (a == "--layers") g_layers = atoi(next("--layers"));
        else if (a == "--ctx") g_ctx = atoi(next("--ctx"));
        else if (a == "--threads") g_threads = atoi(next("--threads"));
        else if (a == "--flash-attn") g_flash_attn = next("--flash-attn");
        else if (a == "--kv-cache") g_kv_cache = next("--kv-cache");
        else if (a == "--mmap") g_mmap = atoi(next("--mmap"));
        else if (a == "--batch") g_batch = atoi(next("--batch"));
        else if (a == "--ubatch") g_ubatch = atoi(next("--ubatch"));
        else if (a == "--max-tokens") g_max_tokens = atoi(next("--max-tokens"));
        else if (a == "--no-infer") g_no_infer = true;
        else if (a == "--no-worker") g_no_worker = true;
        else if (a == "--case") g_case = next("--case");
        else if (a == "--crash-file") g_crash_file = next("--crash-file");
        else if (a == "--log") g_log_file = next("--log");
        else if (a == "--help" || a == "-h") {
            printf("usage: %s --model <gguf> --mmproj <gguf> [options...]\n", argv[0]);
            return false;
        } else {
            fprintf(stderr, "unknown arg: %s\n", a.c_str());
            return false;
        }
    }
    if (!g_model) {
        fprintf(stderr, "missing --model\n");
        return false;
    }
    return true;
}

}  // namespace

int main(int argc, char** argv) {
    if (!parse_args(argc, argv)) return 2;

    // main 线程也装一次，防止崩溃发生在 worker 创建之前
    install_crash_handlers();

    pthread_t tid;
    if (g_no_worker) {
        worker_main(nullptr);
        return 0;
    }
    if (pthread_create(&tid, nullptr, worker_main, nullptr) != 0) {
        fprintf(stderr, "pthread_create failed\n");
        return 2;
    }
    void* ret = nullptr;
    pthread_join(tid, &ret);
    return 0;
}
