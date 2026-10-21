package com.coffeehauslabs.nightingale_tv

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Saving a backup file through the system document picker
 *  (lib/platform/backup_files.dart); opening one goes through file_selector.
 *  Most Android TVs have no picker, and [canPickDocuments] says so. */
class BackupFiles(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var waiting: Pair<MethodChannel.Result, ByteArray>? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canPickDocuments" -> result.success(
                hasPicker(Intent(Intent.ACTION_CREATE_DOCUMENT)) && hasPicker(Intent(Intent.ACTION_OPEN_DOCUMENT))
            )
            "saveDocument" -> {
                val name = call.argument<String>("name")!!
                val bytes = call.argument<ByteArray>("bytes")!!
                waiting?.first?.error("superseded", null, null)
                waiting = result to bytes
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("application/octet-stream")
                    .putExtra(Intent.EXTRA_TITLE, name)
                activity.startActivityForResult(intent, REQUEST_CODE)
            }
            else -> result.notImplemented()
        }
    }

    /** TVs answer document intents with a stub that closes at once. */
    private fun hasPicker(intent: Intent): Boolean {
        intent.addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
        val match = activity.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            ?: return false
        return match.activityInfo.packageName != "com.android.tv.frameworkpackagestubs"
    }

    /** From MainActivity.onActivityResult. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val (result, bytes) = waiting ?: return true
        waiting = null
        val uri: Uri? = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return true
        }
        io.execute {
            try {
                activity.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes) }
                main.post { result.success(true) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
        return true
    }

    companion object {
        private const val REQUEST_CODE = 4202
    }
}
