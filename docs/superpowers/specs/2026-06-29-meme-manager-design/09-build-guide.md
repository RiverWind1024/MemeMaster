# MemeHelper 项目搭建与构建指南

> 所属项目: MemeHelper
> 文档编号: 09-build-guide.md
> 目标平台: Android (arm64-v8a)

---

## 1. 环境要求

### 1.1 必要工具

| 工具 | 版本要求 | 用途 |
|------|---------|------|
| Flutter SDK | ≥3.24, <4.0 | 跨平台框架 |
| Dart SDK | ≥3.5 (随 Flutter 附带) | Dart 语言 |
| Android Studio | ≥2023.1 (Hedgehog) | Android 开发 |
| Android NDK | ≥r26 | 编译 llama.cpp |
| CMake | ≥3.22 | native 编译 |
| Java | ≥17 (Gradle 8.x 要求) | Android 构建 |

### 1.2 验证命令

```bash
# 检查 Flutter
flutter doctor -v

# 输出中必须包含:
#   [✓] Flutter (Channel stable, 3.24.x)
#   [✓] Android toolchain (API 34, NDK 26.x)
#   [✓] Android Studio

# 检查 NDK
ls $ANDROID_HOME/ndk/
# 应看到类似: 26.1.10909125

# 检查 CMake
cmake --version
# ≥ 3.22
```

---

## 2. Flutter 项目初始化

### 2.1 创建项目

```bash
# 在项目父目录执行
flutter create --org com.memehelper --project-name meme_helper \
  --platforms android --android-language kotlin \
  /path/to/MemeHelper

cd /path/to/MemeHelper
```

### 2.2 添加依赖

```yaml
# pubspec.yaml
name: meme_helper
description: Meme 表情包管理工具
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # 数据库
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0

  # sqlite-vec
  sqlite_vec: ^0.1.0

  # 导航
  go_router: ^14.0.0

  # 文件/IO
  archive: ^3.6.0       # ZIP 解压
  crypto: ^3.0.0        # SHA256
  file_picker: ^8.0.0   # 文件选择（备选平台通道方案）

  # 图像
  image: ^4.0.0

  # 安全存储
  flutter_secure_storage: ^9.0.0

  # 后台任务
  workmanager: ^0.5.0

  # S3 客户端
  minio: ^5.0.0

  # FFI
  ffi: ^2.1.0

  # 序列化
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

  # 工具
  collection: ^1.18.0
  equatable: ^2.0.0
  intl: ^0.19.0
  logger: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

  # 代码生成
  drift_dev: ^2.21.0
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0

  # 测试
  mocktail: ^1.0.0
  sqlite3: ^2.0.0        # 内存数据库（测试用）
```

### 2.3 安装依赖

```bash
flutter pub get
```

### 2.4 启用代码生成

```bash
# 初次生成（保持运行，文件修改时自动重新生成）
dart run build_runner watch

# 或一次性生成
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Android 配置

### 3.1 Gradle 配置

```kotlin
// android/app/build.gradle.kts
android {
    namespace = "com.memehelper.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.memehelper.app"
        minSdk = 26           // Android 8.0 (llama.cpp 最低要求)
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        ndk {
            abiFilters += "arm64-v8a"  // 仅支持 64 位 ARM
        }
    }

    // 确保 jniLibs 被包含
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}
```

### 3.2 AndroidManifest 权限

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- 读取外部存储（导入 meme 需要） -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />

    <!-- Android 13+ 使用细粒度权限 -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

    <!-- 网络（S3 同步） -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- 后台任务 -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <!-- 前台服务（分析中） -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

    <application
        android:label="MemeHelper"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- 注册 Platform Channel Plugin -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

    </application>
</manifest>
```

### 3.3 ProGuard 规则

```proguard
# android/app/proguard-rules.pro
# 保留 drift 的 generated 类
-keep class com.memehelper.app.database.** { *; }

# 保留 FFI 调用的 native 方法
-keep class com.memehelper.app.llm.** { *; }

# 保留 JSON 序列化类
-keep class * implements java.io.Serializable { *; }
```

---

## 4. llama.cpp 交叉编译

### 4.1 克隆 llama.cpp

```bash
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
git checkout tags/b3001  # 使用稳定版本
```

### 4.2 设置 NDK 环境变量

```bash
# 设置 NDK 路径（以实际路径为准）
export ANDROID_NDK=$HOME/Android/Sdk/ndk/26.1.10909125

# 设置工具链
export TOOLCHAIN=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64
export API=26
export TARGET=aarch64-linux-android
```

### 4.3 编译

```bash
mkdir build-android && cd build-android

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-26 \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_METAL=OFF \
    -DLLAMA_CUBLAS=OFF \
    -DLLAMA_VULKAN=ON \        # 启用 Vulkan GPU 加速（如设备支持）
    -DCMAKE_BUILD_TYPE=Release

make -j$(nproc)
```

### 4.4 复制产物到 Flutter 项目

```bash
# 创建 jniLibs 目录
mkdir -p /path/to/MemeHelper/android/app/src/main/jniLibs/arm64-v8a

# 复制 .so 文件
cp build-android/src/libllama.so \
   /path/to/MemeHelper/android/app/src/main/jniLibs/arm64-v8a/
cp build-android/ggml/src/libggml.so \
   /path/to/MemeHelper/android/app/src/main/jniLibs/arm64-v8a/

# 验证
ls -lh /path/to/MemeHelper/android/app/src/main/jniLibs/arm64-v8a/
# 应看到:
# -rw-r--r--  libggml.so    (~5MB)
# -rw-r--r--  libllama.so   (~2MB)
```

---

## 5. Drift 代码生成

### 5.1 数据库定义文件

```dart
// lib/core/database/app_database.dart
import 'package:drift/drift.dart';

// 导入所有表定义
part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    MemesTable,
    FoldersTable,
    TagsTable,
    ColorsTable,
    EmbeddingsTable,
    AnalysisQueueTable,
    SyncStateTable,
    SettingsTable,
  ],
  daos: [
    MemeDao,
    FolderDao,
    TagDao,
    ColorDao,
    EmbeddingDao,
    AnalysisQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // 创建 sqlite-vec 虚拟表
      await customStatement(
        'CREATE VIRTUAL TABLE vec_memes USING vec0('
        '  meme_id TEXT PRIMARY KEY,'
        '  vector FLOAT[384]'
        ');'
      );
    },
  );
}
```

### 5.2 执行代码生成

```bash
# 生成 drift 代码（每次修改表定义后重新运行）
dart run build_runner build --delete-conflicting-outputs

# 生成的文件示例:
# lib/core/database/app_database.g.dart
# lib/core/database/tables/memes_table.g.dart
# lib/core/database/daos/meme_dao.g.dart
```

---

## 6. 首次运行验证

### 6.1 创建最小入口

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MemeHelperApp()));
}

class MemeHelperApp extends StatelessWidget {
  const MemeHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MemeHelper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('MemeHelper - 开发中'),
        ),
      ),
    );
  }
}
```

### 6.2 验证清单

```bash
# 1. 代码分析无错误
flutter analyze
# 期望: No issues found!

# 2. 代码生成完成
# 检查 .g.dart 文件是否存在:
ls lib/core/database/*.g.dart  # 应存在

# 3. Android 构建成功
flutter build apk --debug
# 期望: ✓ Built build/app/outputs/flutter-apk/app-debug.apk

# 4. 安装到设备
flutter install
# 期望: 安装成功，App 启动显示 "MemeHelper - 开发中"

# 5. jniLibs 被正确打包
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libllama
# 期望: lib/arm64-v8a/libllama.so
```

---

## 7. 常见问题

### 7.1 llama.cpp 编译失败

```
问题: cmake 找不到 NDK 工具链
解决: 确认 $ANDROID_NDK 指向正确的 NDK 路径
      NDK r26 及以上内置 CMake toolchain

问题: Vulkan 相关编译错误
解决: 移除 -DLLAMA_VULKAN=ON，使用 CPU 推理
      -DLLAMA_VULKAN=OFF

问题: 编译产物过大
解决: 使用 -DCMAKE_BUILD_TYPE=Release 而不是 Debug
```

### 7.2 Drift 代码生成失败

```
问题: build_runner 报 "conflicting outputs"
解决: flutter clean && dart run build_runner build --delete-conflicting-outputs

问题: drift_dev 版本不匹配
解决: 检查 drift 和 drift_dev 版本一致
      都使用 ^2.21.0
```

### 7.3 Android 构建失败

```
问题: minSdk 26 导致兼容性问题
解决: 确认设备 Android 版本 ≥ 8.0

问题: jniLibs 未包含在 APK 中
解决: 检查 android/app/build.gradle.kts 中 jniLibs.srcDirs 配置

问题: INSTALL_FAILED_NO_MATCHING_ABIS
解决: 确认通过 flutter build apk --target-platform android-arm64 构建
```

### 7.4 运行时错误

```
问题: Unable to load libllama.so: dlopen failed
原因: .so 文件未正确打包或设备不是 arm64-v8a
解决: 检查 APK 中是否包含 .so:
     unzip -l app.apk | grep libllama

问题: sqlite-vec: no such module
原因: sqlite-vec 扩展未正确加载
解决: 确保在 AppDatabase 初始化时启用了 sqlite-vec 扩展
```

---

## 8. 开发工作流建议

```bash
# 日常开发:
flutter run                          # 热重载开发

# 代码生成（watch 模式，文件变化自动重新生成）:
dart run build_runner watch

# 运行测试:
flutter test                         # 所有测试
flutter test test/core/database      # 指定模块

# 构建:
flutter build apk --release          # 发布版 APK
flutter build appbundle --release     # AAB 格式（Play Store）

# 分析:
flutter analyze
dart format . --set-exit-if-changed
```
