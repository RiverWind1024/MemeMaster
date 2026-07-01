package com.memehelper.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Environment
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val CHANNEL = "com.memehelper.app/clipboard"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "copyImageToClipboard" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"

                    if (bytes != null) {
                        try {
                            copyImageToClipboard(bytes, mimeType)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("COPY_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARG", "bytes required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun copyImageToClipboard(bytes: ByteArray, mimeType: String) {
        val ext = when {
            mimeType.contains("png") -> ".png"
            mimeType.contains("webp") -> ".webp"
            mimeType.contains("gif") -> ".gif"
            else -> ".jpg"
        }
        val tempFile = File(cacheDir, "clipboard_${System.currentTimeMillis()}$ext")
        tempFile.writeBytes(bytes)

        val uri = FileProvider.getUriForFile(
            this, "${packageName}.fileprovider", tempFile
        )
        val clip = ClipData.newUri(contentResolver, "Meme Image", uri)
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(clip)
    }
}
