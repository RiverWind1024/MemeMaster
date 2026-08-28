package com.mememaster.app.overlay

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.Context
import android.net.Uri
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