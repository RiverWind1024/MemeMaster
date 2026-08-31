# OverlayService Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a foreground service to manage overlay window functionality for the MemeMaster Android app.

**Architecture:** Implement OverlayService as a foreground service with notification channel, handling start/stop actions, and passing image URIs to MainActivity via Intent.

**Tech Stack:** Kotlin, Android SDK, Foreground Service, WindowManager

---

## Task 1: Create OverlayService.kt

**Files:**
- Create: `android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayService.kt`
- Reference: `android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayView.kt`
- Reference: `android/app/src/main/kotlin/com/mememaster/app/MainActivity.kt`

- [ ] **Step 1: Create OverlayService.kt file with provided code**

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

- [ ] **Step 2: Commit the changes**

```bash
git add android/app/src/main/kotlin/com/mememaster/app/overlay/OverlayService.kt
git commit -m "feat(overlay): add OverlayService with foreground notification"
```