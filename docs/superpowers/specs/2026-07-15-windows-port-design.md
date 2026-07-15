# Windows 移植设计方案

**日期**: 2026-07-15
**状态**: 已批准
**目标**: MemeMaster Windows 桌面支持

---

## 一、核心目标

为 MemeMaster 添加 Windows 桌面支持，采用 MVP 策略：

1. **Phase 1**: CPU 推理，Windows 原生运行
2. **Phase 2**: Vulkan GPU 加速（后续可选）

## 二、平台架构

```
windows/
├── cpp/
│   ├── meme_llm.h          # 统一 FFI 接口（复用 Linux 版本）
│   ├── meme_llm.cpp         # Windows 特定实现
│   └── CMakeLists.txt       # 构建配置
├── runner/                   # Flutter Windows runner
└── CMakeLists.txt           # Flutter CMake 集成
```

### 2.1 原生库构建

使用 CMake 构建 `libmeme_llm.dll`：

```bash
cmake -B build -DGGML_VULKAN=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

**Phase 2 启用 Vulkan**:
```bash
cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
```

### 2.2 FFI 绑定

修改 `lib/core/llm/native_bindings.dart`：

```dart
if (Platform.isWindows) {
  candidates.addAll([
    'libmeme_llm.dll',
    'libmeme_llm_empty.dll',
  ]);
} else if (Platform.isLinux) {
  candidates.addAll(['libmeme_llm.so', 'libmeme_llm_empty.so']);
} else if (Platform.isMacOS) {
  candidates.addAll(['libmeme_llm.dylib', 'libmeme_llm_empty.dylib']);
}
```

## 三、OCR 方案

### 3.1 Tesseract OCR 检测

参考 Linux/macOS 现有实现，在 `lib/core/ocr/` 添加 Windows 检测逻辑：

```dart
Future<bool> checkTesseractInstalled() async {
  if (!Platform.isWindows) return false;
  
  // 检测 tesseract 是否在 PATH 中
  final result = await Process.run('where', ['tesseract']);
  return result.exitCode == 0;
}
```

### 3.2 用户提示

检测到 Tesseract 不存在时，提示用户安装：

```
Tesseract OCR 未安装

Windows 版需要 Tesseract 进行文字识别。
请下载安装：
https://github.com/UB-Mannheim/tesseract/wiki

安装后请确保 tesseract 在 PATH 中。
```

## 四、与现有平台对比

| 维度 | Linux | macOS | Windows |
|------|-------|-------|---------|
| **GPU 后端** | Vulkan | Metal | Vulkan (Phase 2) |
| **CPU 推理** | ✅ | ✅ | ✅ |
| **OCR** | Tesseract CLI | Tesseract CLI | Tesseract CLI |
| **原生库格式** | .so | .dylib | .dll |
| **OCR 检测** | 系统命令 | 系统命令 | `where tesseract` |

## 五、CI/CD 新增

### 5.1 Windows Build Job

参考现有 CI 结构（`.github/workflows/ci.yml`）：

```yaml
windows:
  runs-on: windows-latest
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 1
    
    - name: Setup CMake
      uses: actions/checkout@v4
    
    - name: Build meme_llm (CPU only)
      shell: pwsh
      run: |
        cmake -B build -DGGML_VULKAN=OFF -DCMAKE_BUILD_TYPE=Release
        cmake --build build --config Release
    
    - name: Package artifact
      shell: pwsh
      run: |
        Copy-Item build/meme_llm.dll artifacts/windows-cpu/
    
    - name: Upload Windows artifact
      uses: actions/upload-artifact@v4
      with:
        name: mememaster-${{ env.VERSION }}-windows-x64-cpu
        path: artifacts/windows-cpu/
        retention-days: 7
```

### 5.2 Release 更新

新增 Windows artifact 下载和上传：

```yaml
artifacts/windows-cpu/mememaster-${{ env.VERSION }}-windows-x64-cpu.zip
```

## 六、工作流程

```
用户首次运行 Windows 版本
        │
        ▼
┌─────────────────────────┐
│ 检测 tesseract 是否存在  │
└─────────────────────────┘
        │
    不存在 ──────► 提示用户安装
        │                │
     存在              用户安装后
        │                │
        ▼                ▼
  CPU 模式运行        CPU 模式运行
        │
        ▼
  llama.cpp 加载模型
  （暂不支持 Vulkan GPU）
```

## 七、关键文件修改

| 文件 | 操作 | 说明 |
|------|------|------|
| `windows/` | 新增 | Flutter Windows 平台结构 |
| `windows/cpp/` | 新增 | 原生 C++ 代码 |
| `windows/CMakeLists.txt` | 新增 | Flutter CMake 集成 |
| `lib/core/llm/native_bindings.dart` | 修改 | 添加 Windows DLL 加载 |
| `lib/core/ocr/` | 修改 | 添加 Windows Tesseract 检测 |
| `.github/workflows/ci.yml` | 修改 | 添加 windows 构建 job |

## 八、已知限制

1. **Phase 1 无 GPU 加速** - 仅 CPU 推理
2. **Tesseract 需用户安装** - 暂无打包方案
3. **MinGW 编译器** - Vulkan GPU 需 Phase 2 配置 MSVC

## 九、后续扩展

### Phase 2: Vulkan GPU 加速

- 切换到 MSVC 编译器链
- 启用 `GGML_VULKAN=ON`
- 支持 AMD/Intel/NVIDIA GPU

---

**相关文档**:
- [Linux Port Design](./2026-07-09-mememaster-linux-port-design.md)
- [macOS Port Design](./2026-07-10-mememaster-macos-port-design.md)
