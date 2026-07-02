package com.memehelper.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

private const val CHANNEL_CLIPBOARD = "com.memehelper.app/clipboard"
private const val CHANNEL_SHARE = "com.memehelper.app/share"
private const val CHANNEL_STORAGE = "com.memehelper.app/storage"

class MainActivity : FlutterActivity() {
    companion object {
        /// 存储已复制到缓存的路径列表（处理时清空）
        private var pendingCachedPaths: MutableList<String>? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        android.util.Log.d(tag, "configureFlutterEngine called, intent=$intent")

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
                    val paths = pendingCachedPaths?.toList() ?: emptyList()
                    pendingCachedPaths?.clear()
                    android.util.Log.d(tag, "getSharedMedia: returning ${paths.size} paths: $paths")
                    result.success(paths)
                }
                "getClipboardImage" -> {
                    // 在后台线程复制文件，避免大图片阻塞 UI 主线程
                    Thread {
                        try {
                            val path = getClipboardImage()
                            result.success(path)
                        } catch (e: Exception) {
                            android.util.Log.e(tag, "getClipboardImage background failed", e)
                            result.success(null)
                        }
                    }.start()
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_STORAGE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listSafDirectory" -> {
                    Thread {
                        try {
                            val uriStr = call.argument<String>("uri") ?: run {
                                result.error("NO_URI", "uri required", null)
                                return@Thread
                            }
                            val treeUri = Uri.parse(uriStr)
                            val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
                            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocId)
                            val cachedPaths = mutableListOf<String>()

                            contentResolver.query(childrenUri, null, null, null, null)?.use { cursor ->
                                while (cursor.moveToNext()) {
                                    val docId = cursor.getString(cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)) ?: continue
                                    val mime = cursor.getString(cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)) ?: ""
                                    val size = cursor.getLong(cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE))
                                    if (!mime.startsWith("image/")) continue
                                    if (size < 1024 || size > 2 * 1024 * 1024) {
                                        android.util.Log.d(tag, "listSafDirectory: skip $docId size=$size")
                                        continue
                                    }
                                    val fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                                    val cached = copyContentUriToCache(fileUri)
                                    if (cached != null) cachedPaths.add(cached)
                                }
                            }
                            android.util.Log.d(tag, "listSafDirectory: found ${cachedPaths.size} files")
                            result.success(cachedPaths)
                        } catch (e: Exception) {
                            android.util.Log.e(tag, "listSafDirectory failed", e)
                            result.error("LIST_FAILED", e.message, null)
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        android.util.Log.d(tag, "onNewIntent called: action=${intent.action} data=${intent.data}")
        handleIntent(intent)
        // 通知 Flutter 侧立即检查 pending 文件（即使 app 已在前台，不会触发 resume）
        try {
            val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            if (messenger != null) {
                MethodChannel(messenger, CHANNEL_SHARE).invokeMethod("onNewIntent", null)
            }
        } catch (_: Exception) {}
    }

    private val tag = "ShareImport"

    private fun handleIntent(intent: Intent?) {
        if (intent == null) {
            android.util.Log.w(tag, "handleIntent: intent is null")
            return
        }

        val action = intent.action ?: "null"
        val type = intent.type ?: "null"
        android.util.Log.d(tag, "handleIntent: action=$action type=$type")
        android.util.Log.d(tag, "handleIntent: data=${intent.data}")
        android.util.Log.d(tag, "handleIntent: flags=${intent.flags.toHexString()}")

        when (action) {
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                android.util.Log.d(tag, "ACTION_SEND: EXTRA_STREAM=$uri")
                if (uri != null) {
                    addPendingUri(uri)
                } else if (intent.data != null) {
                    // 某些应用把 URI 放在 data 而不是 EXTRA_STREAM
                    android.util.Log.d(tag, "ACTION_SEND: fallback to intent.data")
                    addPendingUri(intent.data!!)
                }
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null) {
                    android.util.Log.d(tag, "ACTION_SEND: EXTRA_TEXT=${text.take(200)}")
                    addPendingText(text)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                android.util.Log.d(tag, "ACTION_SEND_MULTIPLE: ${uris?.size} uris")
                if (uris != null) {
                    for (uri in uris) {
                        android.util.Log.d(tag, "  uri=$uri")
                        addPendingUri(uri)
                    }
                }
            }
            Intent.ACTION_VIEW -> {
                val uri = intent.data
                android.util.Log.d(tag, "ACTION_VIEW: data=$uri type=$type")
                if (uri != null) {
                    // 微信/QQ "其他应用打开" 走这里
                    addPendingUri(uri)
                }
            }
            else -> {
                android.util.Log.w(tag, "unhandled action: $action")
            }
        }
    }

    private fun Int.toHexString(): String {
        return "0x${java.lang.Integer.toHexString(this)}"
    }

    /// 将 URI 立即复制到缓存并记录路径。
    /// 必须在 intent 回调内调用，以利用 intent 授予的临时 URI 权限。
    private fun addPendingUri(uri: Uri) {
        // 尝试1: 标准 contentResolver 读取
        var path: String? = try {
            copyContentUriToCache(uri)
        } catch (e: Exception) {
            android.util.Log.e(tag, "addPendingUri: copyContentUriToCache failed for $uri", e)
            null
        }

        // 尝试2: openInputStream 返回 null 时尝试 takePersistableUriPermission
        if (path == null) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
                android.util.Log.d(tag, "addPendingUri: takePersistableUriPermission OK, retrying")
                path = copyContentUriToCache(uri)
            } catch (e: SecurityException) {
                android.util.Log.w(tag, "addPendingUri: takePersistableUriPermission failed (no persistable flag)", e)
            }
        }

        if (path != null) {
            android.util.Log.d(tag, "addPendingUri: cached $uri -> $path")
            if (pendingCachedPaths == null) pendingCachedPaths = mutableListOf()
            pendingCachedPaths!!.add(path)
        } else {
            android.util.Log.w(tag, "addPendingUri: all attempts failed for $uri, storing as fallback string")
            // fallback: 存 URI 字符串，Flutter 侧导入时会尝试 copyContentUri
            if (pendingCachedPaths == null) pendingCachedPaths = mutableListOf()
            pendingCachedPaths!!.add(uri.toString())
        }
    }

    private fun addPendingText(text: String) {
        android.util.Log.d(tag, "shared text: ${text.take(200)}")
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
            mimeType?.contains("heic") == true -> ".heic"
            mimeType?.contains("heif") == true -> ".heif"
            mimeType?.contains("avif") == true -> ".avif"
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

        // 如果 fileName 已有扩展名（来自 DISPLAY_NAME），不再重复拼接 ext
        val finalName = if (fileName.contains('.')) fileName else "$fileName$ext"

        val destFile = File(cacheDir, "share_import/$finalName")
        destFile.parentFile?.mkdirs()
        destFile.outputStream().use { output ->
            inputStream.copyTo(output)
        }

        // HEIC / HEIF / AVIF → JPEG 转换
        // 这些格式 Android BitmapFactory 原生支持，但 Dart image 包不支持解码
        val unsupportedFormats = listOf(".heic", ".heif", ".avif", ".avifs")
        val lower = finalName.lowercase()
        if (unsupportedFormats.any { lower.endsWith(it) }) {
            try {
                val bmp = BitmapFactory.decodeFile(destFile.absolutePath)
                if (bmp != null) {
                    val jpgName = finalName.substringBeforeLast('.') + ".jpg"
                    val jpgFile = File(cacheDir, "share_import/$jpgName")
                    FileOutputStream(jpgFile).use { out ->
                        bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, out)
                    }
                    destFile.delete()
                    android.util.Log.d(tag, "$finalName converted to JPEG: $jpgFile")
                    return jpgFile.absolutePath
                }
            } catch (e: Exception) {
                android.util.Log.w(tag, "Format conversion failed, keeping original: $finalName", e)
            }
        }

        return destFile.absolutePath
    }

    private fun getClipboardImage(): String? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip ?: run {
            android.util.Log.d(tag, "getClipboardImage: primaryClip is null")
            return null
        }
        if (clip.itemCount == 0) {
            android.util.Log.d(tag, "getClipboardImage: itemCount == 0")
            return null
        }

        val item = clip.getItemAt(0)
        val uri = item.uri
        val mimeType = item.text?.let { "text/plain" } ?: contentResolver.getType(uri)
        android.util.Log.d(tag, "getClipboardImage: uri=$uri mimeType=$mimeType text=${item.text?.toString()?.take(100)}")

        // 尝试1: URI 存在且为图片类型 → 复制到缓存
        if (uri != null) {
            try {
                val resolvedType = contentResolver.getType(uri)
                android.util.Log.d(tag, "getClipboardImage: resolvedType=$resolvedType")
                if (resolvedType?.startsWith("image/") == true) {
                    val path = copyContentUriToCache(uri)
                    if (path != null) {
                        android.util.Log.d(tag, "getClipboardImage: copied image URI to $path")
                        return path
                    }
                }
            } catch (e: Exception) {
                android.util.Log.w(tag, "getClipboardImage: URI fallback - trying openInputStream directly", e)
                // 尝试直接打开（可能没有 MIME type 但有可读内容）
                try {
                    contentResolver.openInputStream(uri)?.use { stream ->
                        val ext = ".png" // 默认 png
                        val destFile = File(cacheDir, "share_import/clipboard_${System.currentTimeMillis()}$ext")
                        destFile.parentFile?.mkdirs()
                        destFile.outputStream().use { stream.copyTo(it) }
                        android.util.Log.d(tag, "getClipboardImage: direct copy success: ${destFile.absolutePath}")
                        return destFile.absolutePath
                    }
                } catch (e2: Exception) {
                    android.util.Log.e(tag, "getClipboardImage: direct openInputStream also failed", e2)
                }
            }
        }

        // 尝试2: 剪贴板内容是文本，可能是文件路径或 URL
        val text = item.text?.toString()
        if (text != null) {
            val trimmed = text.trim()
            android.util.Log.d(tag, "getClipboardImage: text length=${trimmed.length} startsWith=${trimmed.take(50)}")

            // 尝试2a: 本地文件路径
            val extensions = listOf("jpg", "jpeg", "png", "gif", "webp", "bmp")
            var filePath = trimmed
            if (filePath.startsWith("file://")) filePath = filePath.substring(7)
            val ext = filePath.substringAfterLast('.', "").lowercase()
            if (ext in extensions) {
                val file = File(filePath)
                if (file.exists()) {
                    android.util.Log.d(tag, "getClipboardImage: text is local file path: ${file.absolutePath}")
                    return file.absolutePath
                }
            }

            // 尝试2b: HTTP URL（返回特殊前缀让 Flutter 侧下载）
            if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
                if (ext in extensions) {
                    android.util.Log.d(tag, "getClipboardImage: text is HTTP image URL: $trimmed")
                    return "http-url://$trimmed"
                }
            }

            android.util.Log.d(tag, "getClipboardImage: text not a valid image path/URL")
        }

        android.util.Log.d(tag, "getClipboardImage: no image found in clipboard")
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
