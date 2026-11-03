package com.coffeehauslabs.nightingale_tv

import android.app.Activity
import android.content.ClipData
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/** The official app and the own build side by side (install-switching D4, D6):
 *  what kind of install this is, whether the other one is installed, and
 *  handing a backup file straight to it (lib/platform/install_info.dart). */
class InstallSwitching(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    var channel: MethodChannel? = null

    /** What the other app sent, until Dart takes it. */
    private var pending: Map<String, Any?>? = null

    private val ownId: String get() = activity.packageName
    private val ownBuild: Boolean get() = ownId.endsWith(SELF_BUILT)
    private val counterpart: String get() = if (ownBuild) ownId.removeSuffix(SELF_BUILT) else ownId + SELF_BUILT

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> result.success(info())
            "moveSetup" -> moveSetup(call.argument<ByteArray>("bytes")!!, result)
            "askForSetup" -> result.success(send(Intent(ACTION_SEND_SETUP)))
            "takeHandover" -> {
                result.success(pending)
                pending = null
            }
            else -> result.notImplemented()
        }
    }

    private fun info(): Map<String, Any?> {
        val other = try {
            activity.packageManager.getPackageInfo(counterpart, 0)
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
        return mapOf(
            "ownBuild" to ownBuild,
            "installer" to installer(ownId),
            "counterpartInstalled" to (other != null),
            "counterpartInstaller" to other?.let { installer(counterpart) },
            "counterpartFirstInstallTime" to other?.firstInstallTime,
        )
    }

    /** Who installed [id]: the store's package, or null (adb, a file manager…). */
    private fun installer(id: String): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.packageManager.getInstallSourceInfo(id).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getInstallerPackageName(id)
        }
    } catch (e: Exception) {
        null
    }

    /** Writes [bytes] to cache/handover/ and hands it to the other app only. */
    private fun moveSetup(bytes: ByteArray, result: MethodChannel.Result) {
        io.execute {
            try {
                val dir = File(activity.cacheDir, "handover").apply { mkdirs() }
                dir.listFiles()?.forEach { it.delete() }
                val file = File(dir, "setup.ntvbackup")
                file.writeBytes(bytes)
                val uri = FileProvider.getUriForFile(activity, "$ownId.handover", file)
                val intent = Intent(ACTION_RECEIVE_SETUP)
                    .putExtra(Intent.EXTRA_STREAM, uri)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                intent.clipData = ClipData.newRawUri("", uri)
                main.post { result.success(send(intent)) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
    }

    /** Starts the other app's MainActivity, never any other app's. */
    private fun send(intent: Intent): Boolean = try {
        intent.component = ComponentName(counterpart, MainActivity::class.java.name)
        intent.addCategory(Intent.CATEGORY_DEFAULT).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }

    /** From MainActivity, on start and in onNewIntent. */
    fun onIntent(intent: Intent?): Boolean {
        when (intent?.action) {
            ACTION_SEND_SETUP -> deliver(mapOf("kind" to "send"))
            ACTION_RECEIVE_SETUP -> {
                @Suppress("DEPRECATION")
                val uri: Uri? = intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
                    ?: intent.getParcelableExtra(Intent.EXTRA_STREAM)
                io.execute {
                    // At most the cap and one byte, so Dart can say it's too big.
                    val bytes = try {
                        uri?.let { u ->
                            activity.contentResolver.openInputStream(u)?.use { input ->
                                val out = ByteArrayOutputStream()
                                val buffer = ByteArray(64 * 1024)
                                while (out.size() <= MAX_BYTES) {
                                    val n = input.read(buffer)
                                    if (n < 0) break
                                    out.write(buffer, 0, n)
                                }
                                out.toByteArray()
                            }
                        }
                    } catch (e: Exception) {
                        null
                    }
                    main.post { deliver(mapOf("kind" to "receive", "bytes" to (bytes ?: ByteArray(0)))) }
                }
            }
            else -> return false
        }
        return true
    }

    private fun deliver(handover: Map<String, Any?>) {
        pending = handover
        channel?.invokeMethod("handoverArrived", null)
    }

    companion object {
        const val SELF_BUILT = ".selfbuilt"
        const val ACTION_RECEIVE_SETUP = "com.coffeehauslabs.nightingale_tv.action.RECEIVE_SETUP"
        const val ACTION_SEND_SETUP = "com.coffeehauslabs.nightingale_tv.action.SEND_SETUP"

        /** The backup size cap (TransferServer.maxUpload). */
        private const val MAX_BYTES = 32 * 1024 * 1024
    }
}
