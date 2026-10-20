package com.coffeehauslabs.nightingale_tv

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** The device's own pictures, for choosing a channel icon where Android has
 *  no document picker (Android TV, Google TV, Fire TV): Downloads, Pictures,
 *  USB drives, anything MediaStore indexes (lib/platform/device_images.dart). */
class DeviceImages(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var waitingForPermission: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasDocumentPicker" -> result.success(hasDocumentPicker())
            "list" -> withPermission(result) { background(result) { list() } }
            "thumbnail" -> {
                val uri = Uri.parse(call.argument<String>("uri"))
                background(result) { thumbnail(uri) }
            }
            "read" -> {
                val uri = Uri.parse(call.argument<String>("uri"))
                val limit = call.argument<Int>("limit")!!
                background(result) { read(uri, limit) }
            }
            else -> result.notImplemented()
        }
    }

    /** TVs answer "open a document" with a stub that closes at once. */
    private fun hasDocumentPicker(): Boolean {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("image/*")
        val match = activity.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            ?: return false
        return match.activityInfo.packageName != "com.android.tv.frameworkpackagestubs"
    }

    private val permission =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun withPermission(result: MethodChannel.Result, then: () -> Unit) {
        if (activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            then()
            return
        }
        waitingForPermission?.error("superseded", null, null)
        waitingForPermission = result
        pendingAfterPermission = then
        activity.requestPermissions(arrayOf(permission), REQUEST_CODE)
    }

    private var pendingAfterPermission: (() -> Unit)? = null

    /** From MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = waitingForPermission ?: return true
        val then = pendingAfterPermission
        waitingForPermission = null
        pendingAfterPermission = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            then?.invoke()
        } else {
            result.error("denied", "No permission to read pictures", null)
        }
        return true
    }

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
    }

    /** Newest first; still images an icon can come from. */
    private fun list(): List<Map<String, Any?>> {
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val columns = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.MIME_TYPE,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
        )
        val images = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            collection, columns,
            "${MediaStore.Images.Media.MIME_TYPE} IN (?, ?, ?, ?, ?)",
            arrayOf("image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp"),
            "${MediaStore.Images.Media.DATE_MODIFIED} DESC",
        )?.use { c ->
            while (c.moveToNext() && images.size < MAX_IMAGES) {
                val uri = ContentUris.withAppendedId(collection, c.getLong(0))
                images += mapOf(
                    "uri" to uri.toString(),
                    "name" to c.getString(1),
                    "mime" to c.getString(2),
                    "size" to c.getLong(3),
                    "folder" to c.getString(4),
                )
            }
        }
        return images
    }

    private fun thumbnail(uri: Uri): ByteArray {
        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            activity.contentResolver.loadThumbnail(uri, Size(THUMB, THUMB), null)
        } else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            activity.contentResolver.openInputStream(uri)!!.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= THUMB && bounds.outHeight / (sample * 2) >= THUMB) sample *= 2
            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            activity.contentResolver.openInputStream(uri)!!.use { BitmapFactory.decodeStream(it, null, options) }!!
        }
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    /** The file's bytes, at most [limit] + 1 of them (so the caller can tell
     *  it was too big). */
    private fun read(uri: Uri, limit: Int): ByteArray {
        activity.contentResolver.openInputStream(uri)!!.use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            while (out.size() <= limit) {
                val n = input.read(buffer)
                if (n < 0) break
                out.write(buffer, 0, n)
            }
            return out.toByteArray()
        }
    }

    companion object {
        private const val REQUEST_CODE = 4201
        private const val MAX_IMAGES = 500
        private const val THUMB = 256
    }
}
