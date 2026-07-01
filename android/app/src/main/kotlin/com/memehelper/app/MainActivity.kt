package com.memehelper.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

private const val CHANNEL_CLIPBOARD = "com.memehelper.app/clipboard"
private const val CHANNEL_SHARE = "com.memehelper.app/share"

class MainActivity : FlutterActivity() {
    companion object {
        private var pendingShareUris: MutableList<String>? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_CLIPBOARD
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_SHARE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedMedia" -> {
                    val uris = pendingShareUris?.toList() ?: emptyList()
                    pendingShareUris?.clear()
                    if (uris.isNotEmpty()) {
                        val paths = uris.mapNotNull { uriStr ->
                            try {
                                copyContentUriToCache(Uri.parse(uriStr))
                            } catch (e: Exception) {
                                android.util.Log.e("ShareImport", "copy failed: $uriStr", e)
                                null
                            }
                        }
                        result.success(paths)
                    } else {
                        result.success(emptyList<String>())
                    }
                }
                "getClipboardImage" -> {
                    val path = getClipboardImage()
                    result.success(path)
                }
                "copyContentUri" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        try {
                            val realPath = copyContentUriToCache(Uri.parse(uriStr))
                            if (realPath != null) {
                                result.success(realPath)
                            } else {
                                result.error("COPY_FAILED", "copy failed", null)
                            }
                        } catch (e: Exception) {
                            result.error("COPY_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARG", "uri required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (uri != null) {
                    addPendingUri(uri)
                }
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null) {
                    addPendingText(text)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (uris != null) {
                    for (uri in uris) {
                        addPendingUri(uri)
                    }
                }
            }
        }
    }

    private fun addPendingUri(uri: Uri) {
        if (pendingShareUris == null) pendingShareUris = mutableListOf()
        pendingShareUris!!.add(uri.toString())
    }

    private fun addPendingText(text: String) {
        android.util.Log.d("ShareImport", "shared text: $text")
    }

    private fun copyContentUriToCache(uri: Uri): String? {
        val inputStream = contentResolver.openInputStream(uri) ?: return null

        var fileName = "shared_${System.currentTimeMillis()}"
        val mimeType = contentResolver.getType(uri)
        val ext = when {
            mimeType?.contains("png") == true -> ".png"
            mimeType?.contains("webp") == true -> ".webp"
            mimeType?.contains("gif") == true -> ".gif"
            mimeType?.contains("bmp") == true -> ".bmp"
            mimeType?.contains("jpeg") == true -> ".jpg"
            mimeType?.contains("jpg") == true -> ".jpg"
            else -> ".jpg"
        }

        try {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        val name = it.getString(nameIndex)
                        if (name != null) fileName = name
                    }
                }
            }
        } catch (_: Exception) {}

        val destFile = File(cacheDir, "share_import/$fileName$ext")
        destFile.parentFile?.mkdirs()
        destFile.outputStream().use { output ->
            inputStream.copyTo(output)
        }
        return destFile.absolutePath
    }

    private fun getClipboardImage(): String? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip ?: return null
        if (clip.itemCount == 0) return null

        val item = clip.getItemAt(0)
        val uri = item.uri

        if (uri != null) {
            try {
                val mimeType = contentResolver.getType(uri)
                if (mimeType?.startsWith("image/") == true) {
                    return copyContentUriToCache(uri)
                }
            } catch (_: Exception) {}
        }

        val text = item.text?.toString()
        if (text != null) {
            val extensions = listOf("jpg", "jpeg", "png", "gif", "webp", "bmp")
            var filePath = text.trim()
            if (filePath.startsWith("file://")) filePath = filePath.substring(7)
            val ext = filePath.substringAfterLast('.', "").lowercase()
            if (ext in extensions) {
                val file = File(filePath)
                if (file.exists()) {
                    return file.absolutePath
                }
            }
        }

        return null
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
