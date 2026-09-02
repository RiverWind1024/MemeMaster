package com.mememaster.app.overlay

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import java.io.File

/**
 * 透明代理 Activity，用于在 Activity 层读取悬浮窗拖放的 content URI。
 *
 * 背景：拖放权限（requestDragAndDropPermissions）只能在 Activity 上申请，
 * 悬浮窗（Service 管理的 WindowManager View）没有 Activity token 读不到
 * 荣耀等临时 content provider 的图片。因此由悬浮窗把 clipData 连同
 * FLAG_GRANT_READ_URI_PERMISSION 转发给本 Activity，在 onCreate 里同步
 * 读取图片字节写缓存，随后经 OverlayService 通知 Flutter 导入并 finish。
 */
class DropProxyActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        android.util.Log.d("DropProxyActivity", "onCreate, intent.action=${intent?.action}")

        // 立即处理，避免拖放会话超时；整个读取在 onCreate 内同步完成
        try {
            when (intent?.action) {
                ACTION_IMPORT_DROP -> {
                    val path = readFirstImageToCache()
                    if (path != null) {
                        OverlayService.notifyImageImported(this, path)
                    } else {
                        OverlayService.notifyImageImportedFailed("无法读取拖放图片（DropProxy）")
                    }
                }
                else -> android.util.Log.w("DropProxyActivity", "unknown action: ${intent?.action}")
            }
        } catch (e: Exception) {
            android.util.Log.e("DropProxyActivity", "onCreate failed", e)
            OverlayService.notifyImageImportedFailed("读取拖放图片异常: ${e.message}")
        } finally {
            finish()
            overridePendingTransition(0, 0)
        }
    }

    /// 读取 intent.clipData 中的第一张图片到缓存文件，返回真实路径；失败返回 null。
    private fun readFirstImageToCache(): String? {
        val clipData = intent?.clipData ?: run {
            android.util.Log.w("DropProxyActivity", "no clipData")
            return null
        }

        var uri: Uri? = null
        for (i in 0 until clipData.itemCount) {
            val u = clipData.getItemAt(i)?.uri
            if (u != null) {
                uri = u
                break
            }
        }
        if (uri == null) {
            android.util.Log.w("DropProxyActivity", "no uri in clipData")
            return null
        }

        android.util.Log.d("DropProxyActivity", "uri=$uri, mime=${contentResolver.getType(uri)}")

        // 文件名优先从 provider 读取，失败则 fallback
        var fileName = "overlay_${System.currentTimeMillis()}"
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getString(0)
                    if (n != null && n.isNotBlank()) fileName = n
                }
            }
        } catch (_: Exception) {}

        val inputStream = contentResolver.openInputStream(uri) ?: run {
            android.util.Log.w("DropProxyActivity", "openInputStream null for $uri")
            return null
        }

        val mime = contentResolver.getType(uri)
        val ext = when {
            mime?.contains("png") == true -> ".png"
            mime?.contains("webp") == true -> ".webp"
            mime?.contains("gif") == true -> ".gif"
            mime?.contains("bmp") == true -> ".bmp"
            mime?.contains("jpeg") == true -> ".jpg"
            mime?.contains("jpg") == true -> ".jpg"
            mime?.contains("heic") == true -> ".heic"
            mime?.contains("heif") == true -> ".heif"
            else -> ".png"
        }
        if (!fileName.contains('.')) fileName = "$fileName$ext"

        val destFile = File(cacheDir, "share_import/$fileName")
        destFile.parentFile?.mkdirs()
        destFile.outputStream().use { out ->
            inputStream.use { it.copyTo(out) }
        }
        android.util.Log.d("DropProxyActivity", "saved: ${destFile.absolutePath} (${destFile.length()} bytes)")
        return destFile.absolutePath
    }

    companion object {
        const val ACTION_IMPORT_DROP = "com.mememaster.app.action.DROP_PROXY_IMPORT"
    }
}
