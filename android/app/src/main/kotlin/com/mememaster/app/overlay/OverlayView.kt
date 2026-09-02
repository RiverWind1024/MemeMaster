package com.mememaster.app.overlay

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.Context
import android.content.Intent
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
    private var isDragOver = false

    init {
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

                    android.util.Log.d("OverlayView", "ACTION_DROP received, clipData=${event.clipData?.itemCount}")

                    val clipData: ClipData? = event.clipData
                    if (clipData != null && clipData.itemCount > 0 && clipData.getItemAt(0).uri != null) {
                        // 悬浮窗（Service View）没有 Activity token，无法 requestDragAndDropPermissions，
                        // 直接 openInputStream 读不到荣耀等临时 content provider。
                        // 变通：把 clipData 连同 FLAG_GRANT_READ_URI_PERMISSION 转发给
                        // 透明的 DropProxyActivity，由其在 Activity 层读取字节写缓存。
                        val intent = Intent(context, DropProxyActivity::class.java).apply {
                            action = DropProxyActivity.ACTION_IMPORT_DROP
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                            setClipData(clipData)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            context.startActivity(intent)
                            android.util.Log.d("OverlayView", "forwarded drop to DropProxyActivity")
                        } catch (e: Exception) {
                            android.util.Log.e("OverlayView", "failed to start DropProxyActivity", e)
                            onImportFailed("无法启动拖放代理: ${e.message}")
                        }
                    } else {
                        android.util.Log.e("OverlayView", "no clip data with uri on drop")
                        onImportFailed("没有检测到有效图片数据")
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

        isFocusable = false
        isClickable = false
    }

    private fun updateAppearance(isHighlighted: Boolean) {
        val container = findViewById<View>(R.id.overlay_container) ?: return
        if (isHighlighted) {
            container.setBackgroundResource(R.drawable.overlay_bg_active)
            imageView.alpha = 1.0f
            imageView.scaleX = 1.2f
            imageView.scaleY = 1.2f
            textView.text = "松开导入"
            textView.setTextColor(0xFFFFFFFF.toInt())
        } else {
            container.setBackgroundResource(R.drawable.overlay_bg)
            imageView.alpha = 0.85f
            imageView.scaleX = 1.0f
            imageView.scaleY = 1.0f
            textView.text = "拖入图片导入"
            textView.setTextColor(0xFFFFFFFF.toInt())
        }
    }
}
