package com.coffeehauslabs.nightingale_tv

import android.content.Context
import android.media.MediaCodecInfo.CodecCapabilities
import android.media.MediaCodecInfo.CodecProfileLevel
import android.media.MediaCodecList
import android.os.Build
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.audio.AudioCapabilities
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import java.util.Locale

/** What the device plays (design D3), in Jellyfin's codec and profile names,
 *  for the device profile built in lib/playback/android_device_profile.dart:
 *  - video: per codec, what its hardware decoders accept (profiles, bit
 *    depth, largest size and its frame rate, 1080p frame rate);
 *  - audio: the formats a decoder takes, and those the audio output takes
 *    as they are (passthrough over HDMI);
 *  - decoders: every decoder, for the diagnostics log. */
@UnstableApi
object DeviceCapabilities {

    private val videoCodecs = mapOf(
        "video/avc" to "h264",
        "video/hevc" to "hevc",
        "video/x-vnd.on2.vp9" to "vp9",
        "video/x-vnd.on2.vp8" to "vp8",
        "video/av01" to "av1",
        "video/mpeg2" to "mpeg2video",
        "video/mp4v-es" to "mpeg4",
        "video/3gpp" to "h263",
        "video/wvc1" to "vc1",
    )

    private val audioCodecs = mapOf(
        "audio/mp4a-latm" to "aac",
        "audio/mpeg" to "mp3",
        "audio/mpeg-L2" to "mp2",
        "audio/ac3" to "ac3",
        "audio/eac3" to "eac3",
        "audio/eac3-joc" to "eac3",
        "audio/ac4" to "ac4",
        "audio/vnd.dts" to "dts",
        "audio/vnd.dts.hd" to "dts",
        "audio/true-hd" to "truehd",
        "audio/flac" to "flac",
        "audio/opus" to "opus",
        "audio/vorbis" to "vorbis",
        "audio/alac" to "alac",
    )

    /** Formats the audio output may take as they are, by encoding. */
    private val passthrough = listOf(
        C.ENCODING_AC3 to "ac3",
        C.ENCODING_E_AC3 to "eac3",
        C.ENCODING_E_AC3_JOC to "eac3",
        C.ENCODING_DTS to "dts",
        C.ENCODING_DTS_HD to "dts",
        C.ENCODING_DOLBY_TRUEHD to "truehd",
    )

    /** Sizes tried for a decoder's largest, largest first. */
    private val sizes = listOf(
        7680 to 4320, 4096 to 2160, 3840 to 2160, 2560 to 1440, 1920 to 1080, 1280 to 720, 720 to 576, 720 to 480,
    )
    private val rates = listOf(120, 60, 50, 30, 25, 24)

    private val codecInfos: List<android.media.MediaCodecInfo> by lazy {
        MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.filter { !it.isEncoder }
    }

    /** Whether the decoder named [name] runs in hardware: as Android says
     *  (API 29+), or by ExoPlayer's name rule before that. */
    fun isHardware(name: String): Boolean {
        if (Build.VERSION.SDK_INT >= 29) {
            codecInfos.firstOrNull { it.name == name }?.let { return it.isHardwareAccelerated }
        }
        return !softwareByName(name)
    }

    fun isHardware(info: MediaCodecInfo): Boolean = info.hardwareAccelerated

    /** ExoPlayer's rule for API 24–28 (MediaCodecUtil.isSoftwareOnly). */
    private fun softwareByName(codecName: String): Boolean {
        val name = codecName.lowercase(Locale.ROOT)
        if (name.startsWith("arc.")) return false
        return name.startsWith("omx.google.") || name.startsWith("omx.ffmpeg.") ||
            (name.startsWith("omx.sec.") && name.contains(".sw.")) ||
            name == "omx.qcom.video.decoder.hevcswvdec" ||
            name.startsWith("c2.android.") || name.startsWith("c2.google.") ||
            (!name.startsWith("omx.") && !name.startsWith("c2."))
    }

    private fun isAlias(info: android.media.MediaCodecInfo) = Build.VERSION.SDK_INT >= 29 && info.isAlias

    fun query(context: Context): Map<String, Any?> {
        val video = mutableMapOf<String, VideoCaps>()
        val audio = sortedSetOf<String>()
        val decoders = mutableListOf<String>()
        for (info in codecInfos) {
            val hardware = isHardware(info.name)
            for (type in info.supportedTypes) {
                val mime = type.lowercase(Locale.ROOT)
                decoders.add("${info.name} $mime ${if (hardware) "hardware" else "software"}${if (isAlias(info)) " alias" else ""}")
                val caps = try {
                    info.getCapabilitiesForType(type)
                } catch (e: IllegalArgumentException) {
                    continue
                }
                audioCodecs[mime]?.let { audio.add(it) }
                val codec = videoCodecs[mime] ?: continue
                if (!hardware || isAlias(info) || info.name.endsWith(".secure") ||
                    caps.isFeatureRequired(CodecCapabilities.FEATURE_SecurePlayback)
                ) continue
                video.getOrPut(codec) { VideoCaps(codec) }.add(caps)
            }
        }
        // ExoPlayer reads PCM itself.
        audio.add("pcm")
        val output = AudioCapabilities.getCapabilities(context, AudioAttributes.DEFAULT, null)
        val through = passthrough.filter { output.supportsEncoding(it.first) }.map { it.second }.toSortedSet()
        return mapOf(
            "sdk" to Build.VERSION.SDK_INT,
            "video" to video.values.map { it.toMap() },
            "audio" to audio.toList(),
            "passthrough" to through.toList(),
            "maxChannels" to output.maxChannelCount,
            "decoders" to decoders,
        )
    }

    /** One codec's hardware decoders, merged. */
    private class VideoCaps(val codec: String) {
        val profiles = sortedSetOf<String>()
        var bitDepth = 8
        var maxWidth = 0
        var maxHeight = 0
        var maxFps = 0
        var fps1080 = 0

        fun add(caps: CodecCapabilities) {
            for (pl in caps.profileLevels) {
                profileName(codec, pl.profile)?.let { (name, depth) ->
                    profiles.add(name)
                    if (depth > bitDepth) bitDepth = depth
                }
            }
            val v = caps.videoCapabilities ?: return
            val largest = sizes.firstOrNull { (w, h) -> v.isSizeSupported(w, h) } ?: return
            val fps = rateAt(v, largest.first, largest.second)
            if (largest.first * largest.second > maxWidth * maxHeight ||
                (largest.first * largest.second == maxWidth * maxHeight && fps > maxFps)
            ) {
                maxWidth = largest.first
                maxHeight = largest.second
                maxFps = fps
            }
            if (v.isSizeSupported(1920, 1080)) fps1080 = maxOf(fps1080, rateAt(v, 1920, 1080))
        }

        private fun rateAt(v: android.media.MediaCodecInfo.VideoCapabilities, w: Int, h: Int) =
            rates.firstOrNull { v.areSizeAndRateSupported(w, h, it.toDouble()) } ?: 0

        fun toMap() = mapOf(
            "codec" to codec,
            "profiles" to profiles.toList(),
            "bitDepth" to bitDepth,
            "maxWidth" to maxWidth,
            "maxHeight" to maxHeight,
            "maxFps" to maxFps,
            "fps1080" to fps1080,
        )
    }

    /** An Android profile constant as Jellyfin names it (ffprobe's name,
     *  lower case), with the bit depth it decodes; null if Jellyfin has no
     *  condition for it. */
    private fun profileName(codec: String, profile: Int): Pair<String, Int>? = when (codec) {
        "h264" -> when (profile) {
            CodecProfileLevel.AVCProfileBaseline -> "baseline" to 8
            CodecProfileLevel.AVCProfileConstrainedBaseline -> "constrained baseline" to 8
            CodecProfileLevel.AVCProfileMain -> "main" to 8
            CodecProfileLevel.AVCProfileExtended -> "extended" to 8
            CodecProfileLevel.AVCProfileHigh, CodecProfileLevel.AVCProfileConstrainedHigh -> "high" to 8
            CodecProfileLevel.AVCProfileHigh10 -> "high 10" to 10
            CodecProfileLevel.AVCProfileHigh422 -> "high 4:2:2" to 10
            CodecProfileLevel.AVCProfileHigh444 -> "high 4:4:4 predictive" to 10
            else -> null
        }
        "hevc" -> when (profile) {
            CodecProfileLevel.HEVCProfileMain -> "main" to 8
            CodecProfileLevel.HEVCProfileMain10, CodecProfileLevel.HEVCProfileMain10HDR10,
            CodecProfileLevel.HEVCProfileMain10HDR10Plus -> "main 10" to 10
            else -> null
        }
        "vp9" -> when (profile) {
            CodecProfileLevel.VP9Profile0 -> "profile 0" to 8
            CodecProfileLevel.VP9Profile1 -> "profile 1" to 8
            CodecProfileLevel.VP9Profile2, CodecProfileLevel.VP9Profile2HDR,
            CodecProfileLevel.VP9Profile2HDR10Plus -> "profile 2" to 10
            CodecProfileLevel.VP9Profile3, CodecProfileLevel.VP9Profile3HDR,
            CodecProfileLevel.VP9Profile3HDR10Plus -> "profile 3" to 10
            else -> null
        }
        "av1" -> when (profile) {
            CodecProfileLevel.AV1ProfileMain8 -> "main" to 8
            CodecProfileLevel.AV1ProfileMain10, CodecProfileLevel.AV1ProfileMain10HDR10,
            CodecProfileLevel.AV1ProfileMain10HDR10Plus -> "main" to 10
            else -> null
        }
        "mpeg2video" -> when (profile) {
            CodecProfileLevel.MPEG2ProfileSimple -> "simple" to 8
            CodecProfileLevel.MPEG2ProfileMain -> "main" to 8
            CodecProfileLevel.MPEG2Profile422 -> "4:2:2" to 8
            CodecProfileLevel.MPEG2ProfileHigh -> "high" to 8
            else -> null
        }
        else -> null
    }
}
