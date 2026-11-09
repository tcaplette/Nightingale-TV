package io.sentry.flutter

import io.sentry.SentryEvent

/**
 * Nightingale TV: the same personal-data scrub as the app's Dart
 * ReportScrubber (error-reporting design D4), for events the Android SDK
 * sends itself (Java/Kotlin crashes, freezes). Dart events are scrubbed
 * before they get here.
 */
object NightingaleScrub {
  /** The household's names (server names and hosts, users, profiles, the device). */
  @Volatile
  @JvmStatic
  var names: List<String> = emptyList()
    set(value) {
      field = value.map { it.trim() }.filter { it.length >= 2 }.distinct().sortedByDescending { it.length }
    }

  /** The app's breadcrumb categories (ErrorReports.categories in Dart). */
  private val categories = setOf("navigation", "tune", "server", "error")

  private val url = Regex("""(?<![A-Za-z0-9+.\-])(?!file:)[A-Za-z][A-Za-z0-9+.\-]*://[^\s/?#'"<>\\]*""")
  private val ipv4 = Regex("""(?<![\d.])\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?(?![\d.])""")
  private val serverQuery = Regex("""(<server>[^\s?#'"<>]*)\?[^\s#'"<>]*""")
  private val authorization =
    Regex("""((?:X-Emby-|X-MediaBrowser-)?Authorization["']?\s*[=:]\s*)[^\n]*""", RegexOption.IGNORE_CASE)
  private val secret = Regex(
    """((?:X-Plex-Token|X-Emby-Token|X-MediaBrowser-Token|api[_-]?key|access[_-]?token|accesstoken|token|password|passwd|pw)["']?\s*[=:]\s*["']?)([^\s"'&,;<>]+)""",
    RegexOption.IGNORE_CASE)
  private val hex = Regex("""(?<![A-Za-z0-9])[0-9A-Fa-f]{20,}(?![A-Za-z0-9])""")
  private val tokenLike =
    Regex("""(?<![A-Za-z0-9_+=\-])(?=[A-Za-z0-9_+=\-]*\d)(?=[A-Za-z0-9_+=\-]*[A-Za-z])[A-Za-z0-9_+=\-]{20,}""")
  private val androidData =
    Regex("""(?<![\w.~])/(?:data/user/\d+/[^/\s]+|data/data/[^/\s]+|storage/emulated/\d+|sdcard)(?=/|\b)""")

  @JvmStatic
  fun scrub(text: String?): String? {
    if (text == null) return null
    var s = androidData.replace(text, "~")
    s = url.replace(s, "<server>")
    s = ipv4.replace(s, "<server>")
    s = serverQuery.replace(s) { it.groupValues[1] }
    s = authorization.replace(s) { it.groupValues[1] + "<redacted>" }
    s = secret.replace(s) { it.groupValues[1] + "<redacted>" }
    s = hex.replace(s, "<redacted>")
    s = tokenLike.replace(s, "<redacted>")
    for (name in names) {
      s = Regex("(?<![\\p{L}\\p{N}_])" + Regex.escape(name) + "(?![\\p{L}\\p{N}_])", RegexOption.IGNORE_CASE)
        .replace(s, "<name>")
    }
    return s
  }

  @JvmStatic
  fun scrubEvent(event: SentryEvent): SentryEvent {
    event.user = null
    event.request = null
    event.serverName = null
    event.contexts.device?.name = null
    event.message?.let {
      it.formatted = scrub(it.formatted)
      it.message = scrub(it.message)
      it.params = it.params?.map { p -> scrub(p) ?: "" }
    }
    event.exceptions?.forEach { it.value = scrub(it.value) }
    // Only the app's own trail (as Dart's beforeBreadcrumb keeps it), not the
    // Android SDK's network or lifecycle entries.
    event.breadcrumbs = event.breadcrumbs?.filter { it.category in categories }
    event.breadcrumbs?.forEach { it.message = scrub(it.message) }
    return event
  }
}
