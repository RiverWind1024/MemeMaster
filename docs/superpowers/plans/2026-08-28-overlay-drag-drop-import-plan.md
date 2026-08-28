# Overlay Drag-Drop Import Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现Android系统级悬浮窗，支持从微信拖动图片直接导入到MemeMaster

**Architecture:** 使用Android原生WindowManager创建悬浮窗，通过OnDragListener接收跨应用拖放事件，通过MethodChannel将图片URI传递给Flutter层处理导入

**Tech Stack:** Kotlin, Android WindowManager, DragEvent API, Flutter MethodChannel

---

## Chunk 1: 基础权限和悬浮窗服务

### Task 1: 添加Android权限声明

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 添加悬浮窗和前台服务权限**

在 `<manifest>` 标签内，`<application>` 标签前添加：

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- [ ] **Step 2: 注册OverlayService**

在 `<application>` 标签内添加：

```xml
<service
    android:name=".overlay.OverlayService"
    android:foregroundServiceType="specialUse"
    android:enabled="true"
    android:exported="false"/>
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(overlay): add SYSTEM_ALERT_WINDOW and service permissions"
```

### Task 2: 创建OverlayPermissionHelper

**Files:**
- Create: `android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayPermissionHelper.kt`

- [ ] **Step 1: 创建权限帮助类**

```kotlin
package com.mememaster.app.overlay

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

object OverlayPermissionHelper {

    fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    fun requestPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(activity)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
        }
    }

    const val REQUEST_OVERLAY_PERMISSION = 1001
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayPermissionHelper.kt
git commit -m "feat(overlay): add OverlayPermissionHelper"
```

### Task 3: 创建OverlayView

**Files:**
- Create: `android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayView.kt`

- [ ] **Step 1: 创建悬浮窗视图**

```kotlin
package com.mememaster.app.overlay

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.Context
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.view.*
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.mememaster.app.R

@SuppressLint("ViewConstructor")
class OverlayView(
    context: Context,
    private val onImageDropped: (Uri) -> Unit
) : FrameLayout(context) {

    private val imageView: ImageView
    private val textView: TextView
    private var isDragOver = false

    init {
        // 加载悬浮窗布局
        val inflater = LayoutInflater.from(context)
        inflater.inflate(R.layout.overlay_layout, this, true)

        imageView = findViewById(R.id.overlay_image)
        textView = findViewById(R.id.overlay_text)

        setupDragListener()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupDragListener() {
        setOnDragListener { _, event ->
            when (event.action) {
                DragEvent.ACTION_DRAG_STARTED -> {
                    isDragOver = false
                    updateAppearance(false)
                    true
                }

                DragEvent.ACTION_DRAG_ENTERED -> {
                    isDragOver = true
                    updateAppearance(true)
                    true
                }

                DragEvent.ACTION_DRAG_EXITED -> {
                    isDragOver = false
                    updateAppearance(false)
                    true
                }

                DragEvent.ACTION_DROP -> {
                    isDragOver = false
                    updateAppearance(false)

                    val clipData: ClipData? = event.clipData
                    if (clipData != null && clipData.itemCount > 0) {
                        val item = clipData.getItemAt(0)
                        val uri = item.uri

                        if (uri != null) {
                            // 请求拖放权限
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                val permission = requestDragAndDropPermissions(event)
                                permission?.release()
                            }
                            onImageDropped(uri)
                        }
                    }
                    true
                }

                DragEvent.ACTION_DRAG_ENDED -> {
                    isDragOver = false
                    updateAppearance(false)
                    true
                }

                else -> false
            }
        }

        // 允许触摸事件传递到下层应用
        isFocusable = false
        isClickable = false
    }

    private fun updateAppearance(isHighlighted: Boolean) {
        if (isHighlighted) {
            imageView.alpha = 1.0f
            textView.visibility = View.VISIBLE
            setBackgroundColor(0x4000FF00.toInt()) // 半透明绿色
        } else {
            imageView.alpha = 0.6f
            textView.visibility = View.GONE
            setBackgroundColor(0x20000000.toInt()) // 半透明黑色
        }
    }
}
```

- [ ] **Step 2: 创建悬浮窗布局文件**

Create: `android/app/src/main/res/layout/overlay_layout.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="60dp"
    android:layout_height="120dp"
    android:background="#20000000"
    android:padding="8dp">

    <ImageView
        android:id="@+id/overlay_image"
        android:layout_width="40dp"
        android:layout_height="40dp"
        android:layout_gravity="center_horizontal"
        android:src="@mipmap/ic_launcher"
        android:alpha="0.6"/>

    <TextView
        android:id="@+id/overlay_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|center_horizontal"
        android:text="松开导入"
        android:textColor="#00FF00"
        android:textSize="10sp"
        android:visibility="gone"/>

</FrameLayout>
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayView.kt
git add android/app/src/main/res/layout/overlay_layout.xml
git commit -m "feat(overlay): add OverlayView with drag listener"
```

### Task 4: 创建OverlayService

**Files:**
- Create: `android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayService.kt`

- [ ] **Step 1: 创建前台服务**

```kotlin
package com.mememaster.app.overlay

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.mememaster.app.MainActivity
import com.mememaster.app.R

class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "overlay_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "com.mememaster.app.action.START_OVERLAY"
        private const val ACTION_STOP = "com.mememaster.app.action.STOP_OVERLAY"

        fun start(context: Context) {
            val intent = Intent(context, OverlayService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, OverlayService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: OverlayView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startForeground(NOTIFICATION_ID, createNotification())
                showOverlay()
            }
            ACTION_STOP -> {
                hideOverlay()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun showOverlay() {
        if (overlayView != null) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            x = 0
        }

        overlayView = OverlayView(this) { uri ->
            handleImageDropped(uri)
        }

        windowManager?.addView(overlayView, params)
    }

    private fun hideOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
        }
        overlayView = null
    }

    private fun handleImageDropped(uri: Uri) {
        // 通过 Intent 传递 URI 给 MainActivity
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "com.mememaster.app.action.OVERLAY_IMAGE_DROPPED"
            data = uri
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MemeMaster悬浮窗",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "悬浮窗服务通知"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MemeMaster")
            .setContentText("悬浮窗已开启，可拖动图片导入")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayService.kt
git commit -m "feat(overlay): add OverlayService with foreground notification"
```

---

## Chunk 2: Flutter层集成

### Task 5: 添加MethodChannel通信

**Files:**
- Modify: `android/app/src/main/kotlin/com/mememaster/app/MainActivity.kt`
- Modify: `lib/services/shared_media_handler.dart`

- [ ] **Step 1: 在MainActivity中添加Overlay Channel**

在 `MainActivity.kt` 的 `configureFlutterEngine` 方法中添加：

```kotlin
MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "com.mememaster.app/overlay"
).setMethodCallHandler { call, result ->
    when (call.method) {
        "startOverlay" -> {
            if (OverlayPermissionHelper.canDrawOverlays(this)) {
                OverlayService.start(this)
                result.success(true)
            } else {
                result.error("NO_PERMISSION", "悬浮窗权限未授予", null)
            }
        }
        "stopOverlay" -> {
            OverlayService.stop(this)
            result.success(true)
        }
        "canDrawOverlays" -> {
            result.success(OverlayPermissionHelper.canDrawOverlays(this))
        }
        "requestPermission" -> {
            OverlayPermissionHelper.requestPermission(this)
            result.success(true)
        }
        else -> result.notImplemented()
    }
}
```

- [ ] **Step 2: 在handleIntent中处理悬浮窗图片**

在 `MainActivity.kt` 的 `handleIntent` 方法中添加：

```kotlin
"com.mememaster.app.action.OVERLAY_IMAGE_DROPPED" -> {
    val uri = intent.data
    if (uri != null) {
        addPendingUri(uri)
    }
}
```

- [ ] **Step 3: 在SharedMediaHandler中添加Overlay方法**

在 `lib/services/shared_media_handler.dart` 中添加：

```dart
static const MethodChannel _overlayChannel =
    MethodChannel('com.mememaster.app/overlay');

/// 启动悬浮窗
Future<bool> startOverlay() async {
    try {
        final result = await _overlayChannel.invokeMethod<bool>('startOverlay');
        return result ?? false;
    } catch (e) {
        debugPrint('$_tag startOverlay failed: $e');
        return false;
    }
}

/// 停止悬浮窗
Future<bool> stopOverlay() async {
    try {
        final result = await _overlayChannel.invokeMethod<bool>('stopOverlay');
        return result ?? false;
    } catch (e) {
        debugPrint('$_tag stopOverlay failed: $e');
        return false;
    }
}

/// 检查悬浮窗权限
Future<bool> canDrawOverlays() async {
    try {
        final result = await _overlayChannel.invokeMethod<bool>('canDrawOverlays');
        return result ?? false;
    } catch (e) {
        debugPrint('$_tag canDrawOverlays failed: $e');
        return false;
    }
}

/// 请求悬浮窗权限
Future<void> requestOverlayPermission() async {
    try {
        await _overlayChannel.invokeMethod<void>('requestPermission');
    } catch (e) {
        debugPrint('$_tag requestOverlayPermission failed: $e');
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/mememaster/app/MainActivity.kt
git add lib/services/shared_media_handler.dart
git commit -m "feat(overlay): add MethodChannel communication for overlay"
```

### Task 6: 添加Flutter UI控制

**Files:**
- Create: `lib/features/overlay/overlay_controller.dart`
- Create: `lib/features/overlay/overlay_toggle_button.dart`

- [ ] **Step 1: 创建OverlayController**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/shared_media_handler.dart';

class OverlayState {
    final bool isActive;
    final bool hasPermission;

    const OverlayState({
        this.isActive = false,
        this.hasPermission = false,
    });

    OverlayState copyWith({bool? isActive, bool? hasPermission}) {
        return OverlayState(
            isActive: isActive ?? this.isActive,
            hasPermission: hasPermission ?? this.hasPermission,
        );
    }
}

class OverlayController extends StateNotifier<OverlayState> {
    final SharedMediaHandler _handler;

    OverlayController(this._handler) : super(const OverlayState()) {
        _checkPermission();
    }

    Future<void> _checkPermission() async {
        final hasPermission = await _handler.canDrawOverlays();
        state = state.copyWith(hasPermission: hasPermission);
    }

    Future<void> toggle() async {
        if (!state.hasPermission) {
            await _handler.requestOverlayPermission();
            await _checkPermission();
            if (!state.hasPermission) return;
        }

        if (state.isActive) {
            await _handler.stopOverlay();
            state = state.copyWith(isActive: false);
        } else {
            final started = await _handler.startOverlay();
            if (started) {
                state = state.copyWith(isActive: true);
            }
        }
    }
}

final overlayProvider = StateNotifierProvider<OverlayController, OverlayState>((ref) {
    return OverlayController(SharedMediaHandler());
});
```

- [ ] **Step 2: 创建悬浮窗开关按钮**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'overlay_controller.dart';

class OverlayToggleButton extends ConsumerWidget {
    const OverlayToggleButton({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
        final state = ref.watch(overlayProvider);

        return IconButton(
            icon: Icon(
                state.isActive ? Icons.adjust : Icons.circle_outlined,
                color: state.isActive ? Colors.green : Colors.grey,
            ),
            tooltip: state.isActive ? '关闭悬浮窗' : '开启悬浮窗',
            onPressed: () => ref.read(overlayProvider.notifier).toggle(),
        );
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/overlay/overlay_controller.dart
git add lib/features/overlay/overlay_toggle_button.dart
git commit -m "feat(overlay): add Flutter overlay controller and toggle button"
```

### Task 7: 集成到主界面

**Files:**
- Modify: `lib/features/gallery/gallery_screen.dart`

- [ ] **Step 1: 在AppBar中添加悬浮窗开关**

在 `gallery_screen.dart` 的 `AppBar` 的 `actions` 中添加：

```dart
const OverlayToggleButton(),
```

并添加导入：

```dart
import '../overlay/overlay_toggle_button.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/gallery/gallery_screen.dart
git commit -m "feat(overlay): add toggle button to gallery screen"
```

---

## Chunk 3: 测试和优化

### Task 8: 测试基础功能

- [ ] **Step 1: 测试悬浮窗显示**

运行应用，点击悬浮窗开关，验证：
- 悬浮窗显示在屏幕右侧
- 可以上下拖动调整位置
- 前台服务通知显示

- [ ] **Step 2: 测试权限流程**

运行应用，点击悬浮窗开关，验证：
- 首次点击跳转到权限设置页面
- 授权后返回，悬浮窗正常显示
- 拒绝授权，显示提示信息

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test(overlay): verify basic overlay functionality"
```

### Task 9: 测试拖放功能

- [ ] **Step 1: 从微信拖放图片**

测试流程：
1. 开启悬浮窗
2. 打开微信，找到一张图片
3. 长按图片 → 扣图
4. 拖动图片到MemeMaster悬浮窗
5. 验证悬浮窗高亮显示"松开导入"
6. 松开，验证图片导入到MemeMaster

- [ ] **Step 2: 验证导入结果**

验证：
- 图片正确导入到MemeMaster
- 图片显示在图库中
- 图片元数据正确（大小、格式等）

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test(overlay): verify drag-drop import from WeChat"
```

### Task 10: 优化和清理

- [ ] **Step 1: 优化悬浮窗样式**

根据测试反馈调整：
- 悬浮窗大小和位置
- 高亮效果和动画
- 通知样式

- [ ] **Step 2: 添加错误处理**

完善错误处理：
- 权限被拒绝时的提示
- 拖放失败时的提示
- 服务启动失败时的处理

- [ ] **Step 3: 最终Commit**

```bash
git add -A
git commit -m "feat(overlay): complete overlay drag-drop import feature"
```

---

## 验证清单

- [ ] 悬浮窗正常显示和隐藏
- [ ] 可以拖动调整位置
- [ ] 权限流程正常工作
- [ ] 从微信拖放图片成功导入
- [ ] 导入的图片正确显示在MemeMaster中
- [ ] 不影响其他应用的正常使用
- [ ] 服务在后台稳定运行
- [ ] 内存和电量消耗合理
