package com.mememaster.app

import android.os.Bundle
import android.util.Log
import android.view.DragEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import android.app.Activity
import android.graphics.drawable.GradientDrawable
import com.mememaster.app.overlay.OverlayService
import java.io.File
import java.io.FileOutputStream

/**
 * 全屏透明拖放接收页。
 *
 * 悬浮窗 overlay 在拖放开始时启动本页并传入悬浮窗屏幕矩形；本页占满全屏以稳定承接
 * DROP（overlay 不注册 drop target，因此不会挡住本页）。
 *
 * 交互（与"拖到悬浮窗变橙→松开才导入"一致）：
 *  - 指尖进入悬浮窗矩形 => 显示橙色"松开导入"
 *  - 指尖离开悬浮窗矩形 => 隐藏高亮
 *  - 松手：只有在悬浮窗矩形内才导入；范围外直接结束（不导入）
 *
 * 使用原生 Activity（AppCompatActivity 强制 AppCompat 主题，与透明主题不兼容）。
 */
class DragPermissionActivity : Activity() {

    private companion object {
        private fun dp(context: android.content.Context, v: Int): Int =
            (v * context.resources.displayMetrics.density + 0.5f).toInt()
    }

    private var hint: TextView? = null
    private var rectL = 0
    private var rectT = 0
    private var rectR = 0
    private var rectB = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("DragPermission", "onCreate")
        OverlayService.logDebug("全屏透明导入页 onCreate")
        try {
            setup()
        } catch (e: Exception) {
            Log.e("DragPermission", "onCreate 异常", e)
            OverlayService.logDebug("onCreate 异常: ${e.javaClass.simpleName}: ${e.message}")
            try {
                val f = File(filesDir, "spike_crash.txt")
                f.writeText("onCreate: ${e.javaClass.simpleName}: ${e.message}\n${e.stackTraceToString()}")
            } catch (_: Exception) {}
            finish()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // 无论导入成功/失败/取消，结束拖放后恢复悬浮窗药丸显示
        OverlayService.restorePill()
        OverlayService.logDebug("全屏页 onDestroy，恢复悬浮窗")
    }

    private fun setup() {
        window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION

        // 透明背景：不打扰底层内容
        window.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(0x00000000))

        // 悬浮窗可导入/高亮矩形（已放大）
        rectL = intent.getIntExtra("rect_l", -1)
        rectT = intent.getIntExtra("rect_t", -1)
        rectR = intent.getIntExtra("rect_r", -1)
        rectB = intent.getIntExtra("rect_b", -1)
        OverlayService.logDebug("可导入矩形 L=$rectL T=$rectT R=$rectR B=$rectB")

        // 橙色"松开导入"胶囊
        val act = this
        val hint = TextView(this).apply {
            text = "松开导入"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 16f
            setShadowLayer(4f, 0f, 0f, 0xFF000000.toInt())
            setPadding(dp(act, 18), dp(act, 10), dp(act, 18), dp(act, 10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor((0xEEFF8C00).toInt())
                cornerRadius = dp(act, 24).toFloat()
            }
            isClickable = false
            isFocusable = false
            visibility = View.GONE
        }
        this.hint = hint

        val root = FrameLayout(this).apply {
            setBackgroundColor(0x00000000)
            addView(hint, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ))
            setOnDragListener { view, event ->
                when (event.action) {
                    DragEvent.ACTION_DRAG_STARTED -> {
                        centerHint()
                        true
                    }

                    DragEvent.ACTION_DRAG_LOCATION -> {
                        // 实时判定指尖是否在悬浮窗矩形内，动态高亮（仅以此为准，
                        // 避免 ENTERED 在拖放开始就隐藏药丸）
                        setHighlighted(pointInRect(event.x, event.y))
                        true
                    }

                    DragEvent.ACTION_DROP -> {
                        hint.visibility = View.GONE
                        val inRect = pointInRect(event.x, event.y)
                        OverlayService.logDebug("ACTION_DROP at (${event.x},${event.y}) inRect=$inRect")
                        if (!inRect) {
                            OverlayService.logDebug("松手在悬浮窗外，不导入")
                            finish()
                            return@setOnDragListener true
                        }
                        try {
                            val perms = requestDragAndDropPermissions(event)
                            OverlayService.logDebug("requestDragAndDropPermissions -> $perms")
                            handleDrop(event, perms)
                        } catch (e: Exception) {
                            Log.e("DragPermission", "requestDragAndDropPermissions 异常", e)
                            OverlayService.logDebug("requestDragAndDropPermissions 异常: ${e.javaClass.simpleName}: ${e.message}")
                            Toast.makeText(this@DragPermissionActivity, "取权限失败: ${e.message}", Toast.LENGTH_LONG).show()
                        }
                        finish()
                        true
                    }

                    DragEvent.ACTION_DRAG_ENDED -> {
                        hint.visibility = View.GONE
                        OverlayService.logDebug("全屏页 DRAG_ENDED")
                        finish()
                        true
                    }

                    else -> false
                }
            }
        }
        setContentView(root)
    }

    private fun pointInRect(x: Float, y: Float): Boolean {
        if (rectR <= rectL || rectB <= rectT) return false
        return x >= rectL && x <= rectR && y >= rectT && y <= rectB
    }

    /// 同步控制橙色高亮与悬浮窗药丸可见性：
    /// 指尖进入矩形 -> 显示橙色胶囊并隐藏药丸（视觉无缝转交）；
    /// 指尖离开 -> 隐藏橙色并恢复药丸。
    private fun setHighlighted(inRect: Boolean) {
        val h = hint ?: return
        if (inRect) {
            if (h.visibility != View.VISIBLE) {
                h.visibility = View.VISIBLE
                OverlayService.hidePill()
            }
        } else {
            if (h.visibility != View.GONE) {
                h.visibility = View.GONE
                OverlayService.restorePill()
            }
        }
    }

    private fun centerHint() {
        val h = hint ?: return
        if (rectR <= rectL || rectB <= rectT) return
        val cx = (rectL + rectR) / 2f
        val cy = (rectT + rectB) / 2f
        val spec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        h.measure(spec, spec)
        h.setX(cx - h.measuredWidth / 2f)
        h.setY(cy - h.measuredHeight / 2f)
    }

    private fun handleDrop(event: DragEvent, perms: android.view.DragAndDropPermissions?) {
        val clip = event.clipData ?: run {
            Log.e("DragPermission", "clipData 为空")
            OverlayService.logDebug("handleDrop: clipData 为空！")
            return
        }
        OverlayService.logDebug("handleDrop: itemCount=${clip.itemCount}")
        var okCount = 0
        val cachedPaths = mutableListOf<String>()
        for (i in 0 until clip.itemCount) {
            val uri = clip.getItemAt(i).uri ?: continue
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                if (bytes != null && bytes.isNotEmpty()) {
                    val dir = File(cacheDir, "drop_import").apply { mkdirs() }
                    val f = File(dir, "spike_${System.currentTimeMillis()}_$i.png")
                    FileOutputStream(f).use { it.write(bytes) }
                    okCount++
                    cachedPaths.add(f.absolutePath)
                    Log.d("DragPermission", "OK uri=$uri bytes=${bytes.size} -> ${f.absolutePath}")
                    OverlayService.logDebug("OK bytes=${bytes.size}")
                } else {
                    Log.w("DragPermission", "EMPTY uri=$uri")
                    OverlayService.logDebug("读取 EMPTY uri=$uri")
                }
            } catch (e: Exception) {
                Log.e("DragPermission", "FAIL uri=$uri err=${e.javaClass.simpleName}: ${e.message}")
                OverlayService.logDebug("读取 FAIL err=${e.javaClass.simpleName}: ${e.message}")
            }
        }
        if (perms != null) {
            try { perms.release() } catch (_: Exception) {}
        }
        val msg = if (okCount > 0) "成功导入 $okCount 张" else "读取失败，见 logcat"
        Log.d("DragPermission", msg)
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()

        for (p in cachedPaths) {
            OverlayService.notifyImageImported(p)
        }
    }
}
