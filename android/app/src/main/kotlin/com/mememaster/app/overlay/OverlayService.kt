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

        @Volatile
        private var activeView: OverlayView? = null

        /// 记录当前悬浮窗 view（供拖放结束后恢复药丸可见性）
        fun setActiveView(view: OverlayView?) {
            activeView = view
        }

        /// 拖放结束：恢复悬浮窗药丸显示
        fun restorePill() {
            activeView?.setDragVisual(true)
        }

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        /// 拖放诊断：把原生拖放链路各节点反调给 Flutter，进入应用内“运行日志”
        fun logDebug(msg: String) {
            android.util.Log.d("OverlayService", "overlayDebug: $msg")
            try {
                methodChannel?.invokeMethod("onOverlayError", "[拖放] $msg")
            } catch (e: Exception) {
                android.util.Log.e("OverlayService", "logDebug failed", e)
            }
        }

        /// 拖放导入成功：把缓存图片路径反调给 Flutter 导入
        fun notifyImageImported(cachePath: String) {
            android.util.Log.d("OverlayService", "notifyImageImported: $cachePath")
            try {
                methodChannel?.invokeMethod("onOverlayImageImported", cachePath)
            } catch (e: Exception) {
                android.util.Log.e("OverlayService", "notifyImageImported failed", e)
            }
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

        val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
        val savedX = prefs.getInt("pos_x", -1)
        val savedY = prefs.getInt("pos_y", -1)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            // TOP|START 使 x/y 为绝对坐标，便于拖动与位置记忆
            gravity = Gravity.TOP or Gravity.START
            if (savedX < 0 || savedY < 0) {
                // 首次：放置屏幕右边缘上方
                val metrics = resources.displayMetrics
                x = metrics.widthPixels - 170
                y = (metrics.heightPixels * 0.3f).toInt()
                android.util.Log.d("OverlayService", "overlay 初始位置=($x,$y) 屏幕=${metrics.widthPixels}x${metrics.heightPixels}")
            } else {
                x = savedX
                y = savedY
                android.util.Log.d("OverlayService", "overlay 恢复位置=($x,$y)")
            }
        }

        overlayView = OverlayView(
            this,
            onImportFailed = { reason ->
                android.util.Log.w("OverlayService", "image import failed: $reason")
                try {
                    methodChannel?.invokeMethod("onOverlayError", "拖放导入失败: $reason")
                } catch (_: Exception) {}
            }
        )
        OverlayService.setActiveView(overlayView)

        // 注入拖动句柄：更新悬浮窗位置，并在拖动结束后记忆
        overlayView?.attachDragHandle(windowManager!!, params) { px, py ->
            try {
                getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
                    .edit()
                    .putInt("pos_x", px)
                    .putInt("pos_y", py)
                    .apply()
                android.util.Log.d("OverlayService", "保存 overlay 位置=($px,$py)")
            } catch (e: Exception) {
                android.util.Log.w("OverlayService", "保存位置失败: $e")
            }
        }

        windowManager?.addView(overlayView, params)
    }

    private fun hideOverlay() {
        OverlayService.setActiveView(null)
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
