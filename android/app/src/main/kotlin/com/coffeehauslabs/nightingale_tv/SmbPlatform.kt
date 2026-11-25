package com.coffeehauslabs.nightingale_tv

import android.app.Activity
import android.content.Context
import android.net.wifi.WifiManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** What SMB shares need of Android (lib/platform/smb_platform.dart): where
 *  the app's programs are, a key for their passwords, and multicast while
 *  looking for hosts. */
class SmbPlatform(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var multicast: WifiManager.MulticastLock? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "nativeLibraryDir" -> result.success(activity.applicationInfo.nativeLibraryDir)
            "encrypt" -> guarded(result) { encrypt(call.arguments as ByteArray) }
            "decrypt" -> guarded(result) { decrypt(call.arguments as ByteArray) }
            "holdMulticast" -> {
                holdMulticast(call.arguments as Boolean)
                result.success(null)
            }
            "broadcastAddresses" -> guarded(result) { broadcastAddresses() }
            else -> result.notImplemented()
        }
    }

    /** The Keystore can take a moment: never on the main thread. */
    private fun guarded(result: MethodChannel.Result, work: () -> Any) {
        Thread {
            val outcome = runCatching(work)
            activity.runOnUiThread {
                outcome.fold({ result.success(it) }, { result.error("smb", it.javaClass.simpleName, null) })
            }
        }.start()
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(KEY, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build()
            )
        }.generateKey()
    }

    private fun encrypt(data: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        return cipher.iv + cipher.doFinal(data)
    }

    private fun decrypt(data: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, data, 0, NONCE))
        return cipher.doFinal(data, NONCE, data.size - NONCE)
    }

    private fun holdMulticast(hold: Boolean) {
        if (hold) {
            if (multicast != null) return
            val wifi = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
            multicast = wifi.createMulticastLock("nightingale-tv-smb").apply {
                setReferenceCounted(false)
                acquire()
            }
        } else {
            multicast?.release()
            multicast = null
        }
    }

    private fun broadcastAddresses(): List<String> =
        NetworkInterface.getNetworkInterfaces().toList()
            .filter { it.isUp && !it.isLoopback }
            .flatMap { it.interfaceAddresses }
            .mapNotNull { it.broadcast?.hostAddress }
            .distinct()

    fun close() = holdMulticast(false)

    private companion object {
        const val KEY = "nightingale-tv-smb"
        const val NONCE = 12
    }
}
