package com.example.public_file_saver

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/** PublicFileSaverPlugin */
class PublicFileSaverPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val CHANNEL_NAME = "public_file_saver"
        private const val REQUEST_CODE_SAVE_FILE = 7891
    }

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingFileName: String? = null

    /** Delivers method channel results back on the main thread. */
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "saveBytes" -> saveBytes(call, result)
            "saveBytesWithDialog" -> saveBytesWithDialog(call, result)
            else -> result.notImplemented()
        }
    }

    private fun saveBytes(call: MethodCall, result: Result) {
        try {
            val bytes = call.argument<ByteArray>("bytes")
            val fileName = call.argument<String>("fileName")
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            val subDir = call.argument<String>("subDir")

            if (bytes == null || fileName == null) {
                result.error("INVALID_ARGUMENTS", "bytes and fileName are required", null)
                return
            }

            val context = applicationContext
            if (context == null) {
                result.error("NO_CONTEXT", "Application context is null", null)
                return
            }

            // File I/O can be large (this API is used for downloads), so run
            // it off the main thread to avoid ANRs. Results are delivered
            // back on the main thread.
            Thread {
                try {
                    val savedResult =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            // Android 10+ - Use MediaStore
                            saveBytesToMediaStore(context, bytes, fileName, mimeType, subDir)
                        } else {
                            // Android 9 and below - Use public Downloads directory
                            saveBytesToLegacyDownloads(bytes, fileName, subDir)
                        }
                    mainHandler.post { result.success(savedResult) }
                } catch (e: Exception) {
                    mainHandler.post {
                        result.error("SAVE_FAILED", e.message, e.stackTraceToString())
                    }
                }
            }.apply {
                isDaemon = true
                name = "public_file_saver_io"
                start()
            }
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, e.stackTraceToString())
        }
    }

    private fun saveBytesToMediaStore(
        context: Context,
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        subDir: String?
    ): Map<String, Any?> {
        val resolver = context.contentResolver

        val relativePath = if (subDir.isNullOrEmpty()) {
            Environment.DIRECTORY_DOWNLOADS
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$subDir"
        }

        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, contentValues)
            ?: throw Exception("Failed to create MediaStore entry")

        try {
            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
            } ?: throw IOException("Failed to open output stream")

            // Clear pending flag. DISPLAY_NAME/MIME_TYPE/RELATIVE_PATH are
            // re-put because some OEM ROMs require all values on the update
            // for the row to leave the pending state.
            contentValues.clear()
            contentValues.put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            contentValues.put(MediaStore.Downloads.MIME_TYPE, mimeType)
            contentValues.put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            if (resolver.update(uri, contentValues, null, null) <= 0) {
                throw IOException("Failed to publish MediaStore entry")
            }
        } catch (e: Exception) {
            // Do not leave a permanently hidden IS_PENDING row behind after
            // an interrupted or failed write.
            runCatching { resolver.delete(uri, null, null) }
            throw e
        }

        return mapOf(
            "fileName" to fileName,
            "uri" to uri.toString(),
            "path" to null
        )
    }

    @Synchronized
    private fun saveBytesToLegacyDownloads(
        bytes: ByteArray,
        fileName: String,
        subDir: String?
    ): Map<String, Any?> {
        @Suppress("DEPRECATION")
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)

        val targetDir = if (subDir.isNullOrEmpty()) {
            downloadsDir
        } else {
            File(downloadsDir, subDir)
        }

        if (!targetDir.exists() && !targetDir.mkdirs()) {
            throw IOException("Failed to create directory: ${targetDir.absolutePath}")
        }
        if (!targetDir.isDirectory) {
            throw IOException("Save destination is not a directory: ${targetDir.absolutePath}")
        }

        // Handle file name conflicts by adding (1), (2), etc.
        val targetFile = getUniqueFile(targetDir, fileName)

        // Write to a sibling temp file and publish it with a rename so callers
        // never observe a partially-written result.
        val tempFile = File.createTempFile("pfs", ".tmp", targetDir)
        try {
            FileOutputStream(tempFile).use { outputStream ->
                outputStream.write(bytes)
                outputStream.fd.sync()
            }
            if (!tempFile.renameTo(targetFile)) {
                throw IOException("Failed to publish file: ${targetFile.absolutePath}")
            }
        } finally {
            if (tempFile.exists()) {
                tempFile.delete()
            }
        }

        return mapOf(
            "fileName" to targetFile.name,
            "uri" to null,
            "path" to targetFile.absolutePath
        )
    }

    private fun getUniqueFile(directory: File, fileName: String): File {
        var file = File(directory, fileName)
        if (!file.exists()) {
            return file
        }

        val dotIndex = fileName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        val extension = if (dotIndex > 0) fileName.substring(dotIndex) else ""

        var counter = 1
        while (file.exists()) {
            file = File(directory, "$baseName($counter)$extension")
            counter++
        }

        return file
    }

    private fun saveBytesWithDialog(call: MethodCall, result: Result) {
        try {
            val bytes = call.argument<ByteArray>("bytes")
            val fileName = call.argument<String>("fileName")
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

            if (bytes == null || fileName == null) {
                result.error("INVALID_ARGUMENTS", "bytes and fileName are required", null)
                return
            }

            val currentActivity = activity
            if (currentActivity == null) {
                result.error("NO_ACTIVITY", "Activity is not available", null)
                return
            }

            // Store pending data for activity result
            pendingResult = result
            pendingBytes = bytes
            pendingFileName = fileName

            // Launch Storage Access Framework picker
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, fileName)
            }

            currentActivity.startActivityForResult(intent, REQUEST_CODE_SAVE_FILE)
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, e.stackTraceToString())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_SAVE_FILE) {
            return false
        }

        val result = pendingResult
        val bytes = pendingBytes
        val fileName = pendingFileName

        // Clear pending data
        pendingResult = null
        pendingBytes = null
        pendingFileName = null

        if (result == null) {
            return true
        }

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            // User cancelled
            result.success(null)
            return true
        }

        val uri = data.data!!
        val context = applicationContext

        if (context == null || bytes == null) {
            result.error("NO_CONTEXT", "Context or bytes is null", null)
            return true
        }

        // Write off the main thread (the file can be large).
        Thread {
            try {
                context.contentResolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(bytes)
                } ?: throw Exception("Failed to open output stream")

                // Extract file name from URI if possible
                val savedFileName = fileName ?: getFileNameFromUri(context, uri) ?: "saved_file"

                mainHandler.post {
                    result.success(
                        mapOf(
                            "fileName" to savedFileName,
                            "uri" to uri.toString(),
                            "path" to null
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SAVE_FAILED", e.message, e.stackTraceToString())
                }
            }
        }.apply {
            isDaemon = true
            name = "public_file_saver_dialog_io"
            start()
        }

        return true
    }

    private fun getFileNameFromUri(context: Context, uri: Uri): String? {
        var fileName: String? = null
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    fileName = cursor.getString(nameIndex)
                }
            }
        }
        return fileName
    }
}

