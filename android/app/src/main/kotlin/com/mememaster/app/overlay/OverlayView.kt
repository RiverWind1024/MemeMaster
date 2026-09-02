package com.mememaster.app.overlay

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.view.*
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.mememaster.app.R
import java.io.File

@SuppressLint("ViewConstructor")
class OverlayView(
    context: Context,
    private val onImageImported: (String) -> Unit,
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
                    if (clipData != null && clipData.itemCount > 0) {
                        val item = clipData.getItemAt(0)
                        val uri = item.uri
                        android.util.Log.d("OverlayView", "drop item uri=$uri")

                        if (uri != null) {
                            // 关键：在 ACTION_DROP 回调中直接读取字节，
                            // 此时系统仍授予了临时 URI 读取权限
                            val path = readUriToCache(uri)
                            if (path != null) {
                                android.util.Log.d("OverlayView", "read success: $path")
                                onImageImported(path)
                            } else {
                                val mime = try { context.contentResolver.getType(uri) } catch (e: Exception) { "getType err: ${e.message}" }
                                android.util.Log.e("OverlayView", "readUriToCache returned null, uri=$uri, mime=$mime")
                                onImportFailed("无法读取拖放图片 (uri=$uri, mime=$mime)")
                            }
                        } else {
                            android.util.Log.e("OverlayView", "drop item has no uri")
                            onImportFailed("拖放数据不含 URI")
                        }
                    } else {
                        android.util.Log.e("OverlayView", "no clip data on drop")
                        onImportFailed("没有检测到拖放数据")
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

    /**
     * 在 ACTION_DROP 回调中直接读取 content URI 到缓存文件。
     * 此时系统仍授予了临时读取权限（DragEvent 的 ClipData 权限）。
     */
    private fun readUriToCache(uri: Uri): String? {
        return try {
            val ctx = context

            // 尝试读取文件名
            var fileName = "overlay_${System.currentTimeMillis()}"
            try {
                ctx.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex >= 0) {
                            val name = cursor.getString(nameIndex)
                            if (name != null) fileName = name
                        }
                    }
                }
            } catch (_: Exception) {}

            // 读取字节
            val inputStream = ctx.contentResolver.openInputStream(uri) ?: run {
                android.util.Log.w("OverlayView", "openInputStream returned null for $uri")
                return null
            }

            // 确定扩展名
            val ext = if (fileName.contains('.')) {
                fileName.substringAfterLast('.')
            } else {
                val mimeType = ctx.contentResolver.getType(uri)
                when {
                    mimeType?.contains("png") == true -> "png"
                    mimeType?.contains("webp") == true -> "webp"
                    mimeType?.contains("gif") == true -> "gif"
                    mimeType?.contains("jpeg") == true -> "jpg"
                    mimeType?.contains("jpg") == true -> "jpg"
                    else -> "jpg"
                }
            }
            if (!fileName.contains('.')) fileName = "$fileName.$ext"

            val destFile = File(ctx.cacheDir, "share_import/$fileName")
            destFile.parentFile?.mkdirs()
            destFile.outputStream().use { output ->
                inputStream.use { input ->
                    input.copyTo(output)
                }
            }

            android.util.Log.d("OverlayView", "readUriToCache: $uri -> ${destFile.absolutePath} (${destFile.length()} bytes)")
            destFile.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("OverlayView", "readUriToCache failed for $uri", e)
            null
        }
    }

    private fun updateAppearance(isHighlighted: Boolean) {
        if (isHighlighted) {
            imageView.alpha = 1.0f
            textView.visibility = View.VISIBLE
            setBackgroundColor(0x4000FF00.toInt())
        } else {
            imageView.alpha = 0.6f
            textView.visibility = View.GONE
            setBackgroundColor(0x20000000.toInt())
        }
    }
}
