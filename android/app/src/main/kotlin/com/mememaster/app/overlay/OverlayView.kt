package com.mememaster.app.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.view.*
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.mememaster.app.R

@SuppressLint("ViewConstructor")
class OverlayView(
    context: Context,
    private val onImportFailed: (String) -> Unit = {}
) : FrameLayout(context) {

    private val imageView: ImageView
    private val textView: TextView

    // 拖动相关：由 OverlayService 在 addView 前注入
    private var windowManager: android.view.WindowManager? = null
    private var layoutParams: android.view.WindowManager.LayoutParams? = null
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var paramsStartX = 0
    private var paramsStartY = 0
    private var onPositionChanged: ((Int, Int) -> Unit)? = null

    init {
        val inflater = LayoutInflater.from(context)
        inflater.inflate(R.layout.overlay_layout, this, true)

        imageView = findViewById(R.id.overlay_image)
        textView = findViewById(R.id.overlay_text)

        setupDragListener()
        setupTouchMove()
    }

    /// 由 OverlayService 注入 WindowManager、当前 LayoutParams 与位置持久化回调
    fun attachDragHandle(
        windowManager: android.view.WindowManager,
        layoutParams: android.view.WindowManager.LayoutParams,
        onPositionChanged: (Int, Int) -> Unit
    ) {
        this.windowManager = windowManager
        this.layoutParams = layoutParams
        this.onPositionChanged = onPositionChanged
    }

    private fun setupTouchMove() {
        setOnTouchListener { _, event ->
            val params = layoutParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    paramsStartX = params.x
                    paramsStartY = params.y
                    android.util.Log.d("OverlayView", "touch DOWN 起点=(${touchStartX.toInt()},${touchStartY.toInt()}) params=(${params.x},${params.y})")
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchStartX).toInt()
                    val dy = (event.rawY - touchStartY).toInt()
                    params.x = paramsStartX + dx
                    params.y = paramsStartY + dy
                    try {
                        windowManager?.updateViewLayout(this, params)
                    } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    android.util.Log.d("OverlayView", "touch UP 拖动结束 新位置=(${params.x},${params.y})")
                    onPositionChanged?.invoke(params.x, params.y)
                    true
                }
                else -> false
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupDragListener() {
        setOnDragListener { _, event ->
            // 悬浮窗只负责在拖放开始时启动承载导入的全屏透明页。
            // 关键：这里始终返回 false，使悬浮窗不被注册为 drop target，
            // 从而不拦截 DROP，让拖放命中测试穿透到下面的全屏透明 Activity。
            if (event.action == DragEvent.ACTION_DRAG_STARTED) {
                OverlayService.logDebug("悬浮窗收到 DRAG_STARTED，启动全屏透明导入页")
                launchDropPermissionActivity()
            }
            false
        }

        isFocusable = false
        isClickable = true
    }

    /// 拖放期间隐藏悬浮窗药丸，把视觉完全交给透明页的橙色高亮（避免文字互相遮挡）
    fun setDragVisual(active: Boolean) {
        val view = this
        view.post {
            view.visibility = if (active) View.VISIBLE else View.INVISIBLE
        }
    }

    /// 拖放开始：把"放大的可导入矩形"传给全屏透明 DragPermissionActivity。
    /// 判定区域刻意大于药丸，方便用户对准（药丸视觉居中，周围留白也计入可导入区）。
    private fun launchDropPermissionActivity() {
        android.util.Log.d("OverlayView", "DRAG_STARTED, launching DragPermissionActivity")
        try {
            val px = layoutParams?.x ?: 0
            val py = layoutParams?.y ?: 0
            val pw = if (width > 0) width else (resources.displayMetrics.widthPixels / 4)
            val ph = if (height > 0) height else (resources.displayMetrics.heightPixels / 10)
            val cx = px + pw / 2
            val cy = py + ph / 2
            // 在药丸基础上向外扩展，扩大可导入/高亮判定区域（单位：dp）
            val padH = (48 * resources.displayMetrics.density).toInt()
            val padV = (48 * resources.displayMetrics.density).toInt()
            val xl = cx - pw / 2 - padH
            val yt = cy - ph / 2 - padV
            val xr = cx + pw / 2 + padH
            val yb = cy + ph / 2 + padV
            val intent = android.content.Intent(context, com.mememaster.app.DragPermissionActivity::class.java).apply {
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra("rect_l", xl)
                putExtra("rect_t", yt)
                putExtra("rect_r", xr)
                putExtra("rect_b", yb)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("OverlayView", "启动 DragPermissionActivity 失败", e)
            try {
                val f = java.io.File(context.filesDir, "spike_crash.txt")
                f.writeText("${e.javaClass.simpleName}: ${e.message}\n${e.stackTraceToString()}")
            } catch (_: Exception) {}
            onImportFailed("启动导入通道失败: ${e.message}")
        }
    }
}
