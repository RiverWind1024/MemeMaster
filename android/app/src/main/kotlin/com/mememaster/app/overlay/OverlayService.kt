package com.mememaster.app.overlay

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.mememaster.app.MainActivity
import com.mememaster.app.R
import io.flutter.plugin.common.MethodChannel

class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "overlay_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "com.mememaster.app.action.START_OVERLAY"
        private const val ACTION_STOP = "com.mememaster.app.action.STOP_OVERLAY"
        const val CHANNEL_OVERLAY = "com.mememaster.app/overlay"

        private var methodChannel: MethodChannel? = null

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

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
                try {
                    startForeground(NOTIFICATION_ID, createNotification())
                    showOverlay()
                } catch (e: Exception) {
                    android.util.Log.e("OverlayService", "Failed to start overlay", e)
                    // 通过 MethodChannel 反调 Flutter，让用户能在日志查看器看到错误
                    try {
                        methodChannel?.invokeMethod(
                            "onOverlayError",
                            "启动悬浮窗失败: ${e.javaClass.simpleName}: ${e.message}"
                        )
                    } catch (_: Exception) {}
                    stopSelf()
                }
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

        overlayView = OverlayView(
            this,
            onImageImported = { cachePath ->
                // 直接通过 MethodChannel 通知 Flutter 导入
                android.util.Log.d("OverlayService", "image imported to cache: $cachePath")
                try {
                    methodChannel?.invokeMethod("onOverlayImageImported", cachePath)
                } catch (e: Exception) {
                    android.util.Log.e("OverlayService", "Failed to invoke onOverlayImageImported", e)
                    // 回退：通过 Intent 发送给 MainActivity
                    fallbackViaIntent(cachePath)
                }
            },
            onImportFailed = {
                android.util.Log.w("OverlayService", "image import failed from overlay drop")
            }
        )

        windowManager?.addView(overlayView, params)
    }

    private fun fallbackViaIntent(cachePath: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "com.mememaster.app.action.OVERLAY_IMAGE_DROPPED"
            putExtra("cached_path", cachePath)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
    }

    private fun hideOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
        }
        overlayView = null
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
            .setSmallIcon(R.drawable.ic_overlay_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }
}
