# Windows 移植实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MemeMaster Windows 桌面支持，Phase 1 CPU 推理

**Architecture:** 通过 FFI 加载 Windows 原生 `libmeme_llm.dll`，复用现有 llama.cpp 封装接口，Tesseract OCR 检测 + 提示安装。

**Tech Stack:** Flutter Windows, CMake, FFI (dart:ffi), llama.cpp

---

## 文件结构

```
windows/
├── cpp/
│   ├── meme_llm.h          # 复制自 linux/cpp/meme_llm.h
│   ├── meme_llm.cpp       # 基于 linux/cpp/meme_llm.cpp，Windows 特定初始化
│   └── CMakeLists.txt      # CMake 构建配置（CPU only，Vulkan 可选）
├── runner/
│   └── (Flutter Windows runner files - 标准生成)
└── CMakeLists.txt          # Flutter CMake 集成

lib/core/llm/
└── native_bindings.dart    # 修改: 添加 Windows DLL 加载分支

lib/core/ocr/
└── tesseract_ocr_service.dart  # 修改: 添加 Windows where 命令检测
```

---

## Chunk 1: Windows 目录结构

### Task 1: 创建 windows/cpp/ 目录和 meme_llm.h

**Files:**
- Create: `windows/cpp/meme_llm.h`
- Reference: `linux/cpp/meme_llm.h` (直接复制)

- [ ] **Step 1: 复制 meme_llm.h**

```bash
cp linux/cpp/meme_llm.h windows/cpp/meme_llm.h
```

- [ ] **Step 2: Commit**

```bash
git add windows/cpp/meme_llm.h
git commit -m "feat(windows): copy meme_llm.h header from linux"
```

---

### Task 2: 创建 windows/cpp/CMakeLists.txt

**Files:**
- Create: `windows/cpp/CMakeLists.txt`
- Reference: `linux/cpp/CMakeLists.txt`

- [ ] **Step 1: 创建 CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.16)
project(meme_llm_windows CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# llama.cpp 路径（假设在 third_party/llama.cpp）
set(LLAMA_DIR "${CMAKE_SOURCE_DIR}/../../third_party/llama.cpp")
set(LLAMA_BUILD_DIR "${CMAKE_SOURCE_DIR}/../../third_party/llama.cpp/build")

# 查找 llama.cpp
add_subdirectory(${LLAMA_DIR} llama.cpp EXCLUDE_FROM_ALL)

# 源文件
set(SOURCES
    meme_llm.cpp
)

# 生成 DLL
add_library(meme_llm SHARED ${SOURCES})

target_include_directories(meme_llm PRIVATE
    ${LLAMA_DIR}
    ${LLAMA_DIR}/include
)

target_link_libraries(meme_llm PRIVATE
    llama
    common
)

# Windows 特定配置
if(WIN32)
    target_compile_definitions(meme_llm PRIVATE _WIN32_WINNT=0x0601)
endif()
```

- [ ] **Step 2: Commit**

```bash
git add windows/cpp/CMakeLists.txt
git commit -m "feat(windows): add CMakeLists.txt for meme_llm DLL build"
```

---

### Task 3: 创建 windows/CMakeLists.txt

**Files:**
- Create: `windows/CMakeLists.txt`
- Reference: `linux/CMakeLists.txt`

- [ ] **Step 1: 检查 linux/CMakeLists.txt 结构**

```bash
head -50 linux/CMakeLists.txt
```

- [ ] **Step 2: 创建 windows/CMakeLists.txt**

Flutter Windows 标准结构，基于 linux/CMakeLists.txt 调整

- [ ] **Step 3: Commit**

```bash
git add windows/CMakeLists.txt
git commit -m "feat(windows): add Flutter CMakeLists.txt integration"
```

---

## Chunk 2: Windows 原生代码实现

### Task 4: 创建 windows/cpp/meme_llm.cpp

**Files:**
- Create: `windows/cpp/meme_llm.cpp`
- Reference: `linux/cpp/meme_llm.cpp`

- [ ] **Step 1: 复制并修改 meme_llm.cpp**

关键修改点：
1. Windows 日志宏（用 OutputDebugString 或 fprintf）
2. Windows 线程互斥（用 CRITICAL_SECTION 或 pthread-win32）
3. 禁用 Vulkan GPU（Phase 1 CPU only）

```cpp
// windows/cpp/meme_llm.cpp

// 复制 linux/cpp/meme_llm.cpp 内容，修改：

// 1. 日志宏改为 Windows 兼容
#ifdef _WIN32
#define MLLM_LOGI(...) fprintf(stderr, __VA_ARGS__)
#define MLLM_LOGW(...) fprintf(stderr, __VA_ARGS__)
#define MLLM_LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

// 2. pthread 替换为 Windows 线程
// 使用 HANDLE, WaitForSingleObject 等替代 pthread

// 3. sigsetjmp/siglongjmp 在 Windows 上的处理
// 可选：禁用 GPU 崩溃捕获
```

- [ ] **Step 2: Commit**

```bash
git add windows/cpp/meme_llm.cpp
git commit -m "feat(windows): implement meme_llm.cpp for Windows"
```

---

## Chunk 3: FFI 绑定修改

### Task 5: 修改 native_bindings.dart 添加 Windows 支持

**Files:**
- Modify: `lib/core/llm/native_bindings.dart`
- Reference: `lib/core/llm/native_bindings.dart` (现有实现)

- [ ] **Step 1: 读取现有实现**

```dart
// 查看 DynamicLibrary.open 部分
grep -n "DynamicLibrary.open" lib/core/llm/native_bindings.dart
```

- [ ] **Step 2: 添加 Windows DLL 加载分支**

```dart
// 在 Platform.isWindows 分支添加：
if (Platform.isWindows) {
  candidates.addAll([
    'libmeme_llm.dll',
    'libmeme_llm_empty.dll',
  ]);
}
```

- [ ] **Step 3: 测试 Windows FFI 加载**

需要实际在 Windows 环境测试，此步骤留待 CI 验证

- [ ] **Step 4: Commit**

```bash
git add lib/core/llm/native_bindings.dart
git commit -m "feat(windows): add Windows DLL loading in native bindings"
```

---

## Chunk 4: OCR 检测

### Task 6: 修改 tesseract_ocr_service.dart 添加 Windows 检测

**Files:**
- Modify: `lib/core/ocr/tesseract_ocr_service.dart`
- Reference: `linux/cpp/meme_llm.cpp` OCR 实现

- [ ] **Step 1: 检查现有 OCR 服务实现**

```bash
find lib/core/ocr -name "*.dart" -type f
```

- [ ] **Step 2: 添加 Windows where 命令检测**

```dart
Future<bool> checkTesseractInstalled() async {
  if (!Platform.isWindows) {
    // Linux/macOS 检测逻辑
    final result = await Process.run('which', ['tesseract']);
    return result.exitCode == 0;
  }
  
  // Windows: 使用 where 命令
  final result = await Process.run('where', ['tesseract.exe']);
  return result.exitCode == 0;
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/ocr/
git commit -m "feat(windows): add Tesseract detection for Windows"
```

---

## Chunk 5: CI/CD

### Task 7: 添加 Windows CI job

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: 读取现有 CI 结构**

```bash
grep -n "linux:" .github/workflows/ci.yml | head -5
```

- [ ] **Step 2: 添加 windows job**

```yaml
windows:
  runs-on: windows-latest
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 1
    
    - name: Setup CMake
      shell: pwsh
      run: |
        cmake --version
    
    - name: Clone llama.cpp
      shell: pwsh
      run: |
        git clone --depth 1 https://github.com/ggml-org/llama.cpp.git ../third_party/llama.cpp
    
    - name: Configure CMake
      shell: pwsh
      run: |
        cmake -S windows/cpp -B build -DGGML_VULKAN=OFF
    
    - name: Build DLL
      shell: pwsh
      run: |
        cmake --build build --config Release
    
    - name: Create artifact directory
      shell: pwsh
      run: |
        mkdir -p artifacts/windows-cpu
        cp build/Release/*.dll artifacts/windows-cpu/ 2>/dev/null || cp build/*.dll artifacts/windows-cpu/
    
    - name: Upload artifact
      uses: actions/upload-artifact@v4
      with:
        name: mememaster-${{ env.VERSION }}-windows-x64-cpu
        path: artifacts/windows-cpu/
        retention-days: 7
```

- [ ] **Step 3: 添加 windows job 到 release needs**

```yaml
release:
  needs: [linux, linux-cpu, macos, macos-cpu, android-vulkan, android-cpu, windows]
```

- [ ] **Step 4: 添加 Windows artifact 下载**

```yaml
      - name: Download Windows
        uses: actions/download-artifact@v4
        with:
          name: mememaster-${{ env.VERSION }}-windows-x64-cpu
          path: artifacts/windows-cpu
```

- [ ] **Step 5: 添加 Windows 到 release files**

```yaml
          files: |
            ...
            artifacts/windows-cpu/mememaster-${{ env.VERSION }}-windows-x64-cpu.zip
```

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "feat(windows): add Windows CI job and release artifact"
```

---

## Chunk 6: 文档更新

### Task 8: 更新 README 和开发文档

**Files:**
- Modify: `README.md`
- Modify: `docs/DEVELOPMENT.md`

- [ ] **Step 1: 更新 README.md**

在"支持平台"部分添加 Windows

- [ ] **Step 2: 更新 docs/DEVELOPMENT.md**

添加 Windows 构建说明

- [ ] **Step 3: Commit**

```bash
git add README.md docs/DEVELOPMENT.md
git commit -m "docs: update README and development docs for Windows"
```

---

## 验证清单

- [ ] `windows/cpp/meme_llm.h` 存在
- [ ] `windows/cpp/meme_llm.cpp` 存在
- [ ] `windows/cpp/CMakeLists.txt` 存在
- [ ] `windows/CMakeLists.txt` 存在
- [ ] `native_bindings.dart` 包含 Windows DLL 加载
- [ ] `tesseract_ocr_service.dart` 包含 Windows 检测
- [ ] CI workflow 包含 windows job
- [ ] 本地测试：`flutter build windows --release` 成功
