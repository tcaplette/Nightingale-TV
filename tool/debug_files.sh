# Release debug files (library-scan-anr D3), sourced by tool/build_*.sh.
#
# Each official build saves the debug information of its compiled Dart code
# (libapp.so) next to the release, in <dist>/symbols/libapp-<abi>.debug,
# with gen_snapshot's --save-debugging-info. Without --split-debug-info, so
# Dart stack traces keep their function names. tool/symbolize_event.py reads
# the files to turn an ANR's or native crash's libapp.so frames into Dart
# functions with file and line. They never go inside an APK, bundle, .deb
# or tarball.

# The flutter build option that saves [file].
debug_files_option() {
  echo "--extra-gen-snapshot-options=--save-debugging-info=$1"
}

# A new name to save [1]'s debug file under for one build. Flutter reuses an
# unchanged build's compiled code without running gen_snapshot, which would
# then write no file; a name used once changes the build's options, so the
# code is always compiled and the file always written. [debug_files_keep]
# moves it to [1].
debug_files_fresh() {
  echo "${1%.debug}.$$.$(date +%s%N).partial"
}

# Checks the file a build saved at [1], then moves it to [2]. Partial files
# that failed builds left for [2] go.
debug_files_keep() {
  debug_files_saved "$1" || return 1
  mv -f "$1" "$2"
  find "$(dirname "$2")" -maxdepth 1 -name "$(basename "${2%.debug}").*.partial" -delete
}

# A program that reads ELF notes: binutils readelf, else the NDK's.
debug_files_readelf() {
  if command -v readelf >/dev/null 2>&1; then
    command -v readelf
    return
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
  local ndk
  ndk="$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1)"
  if [[ -n "$ndk" && -x "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf" ]]; then
    echo "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"
    return
  fi
  echo "No readelf found: install binutils (or the Android NDK) to check release debug files." >&2
  return 1
}

# The GNU build ID of ELF file [1].
debug_files_build_id() {
  "$(debug_files_readelf)" -n "$1" | sed -n 's/^[[:space:]]*Build ID:[[:space:]]*//p' | head -1
}

# Fails unless [1] (a debug file) exists and has a build ID.
debug_files_saved() {
  if [[ ! -s "$1" ]]; then
    echo "The debug file $1 wasn't saved." >&2
    return 1
  fi
  if [[ -z "$(debug_files_build_id "$1")" ]]; then
    echo "The debug file $1 has no build ID." >&2
    return 1
  fi
}

# Checks every lib/<abi>/libapp.so in archive [1] (APK or bundle) against
# <symbols dir [2]>/libapp-<abi>.debug, and that [1] holds no debug file.
# Fails naming the archive and ABI of the first mismatch.
debug_files_check_android() {
  local archive="$1" symbols="$2" tmp entries entry abi so want got found=0
  entries="$(unzip -Z1 "$archive")"
  if grep -E '\.debug$|(^|/)symbols/' <<<"$entries" >/dev/null; then
    echo "$(basename "$archive") holds a debug file:" >&2
    grep -E '\.debug$|(^|/)symbols/' <<<"$entries" >&2
    return 1
  fi
  tmp="$(mktemp -d)"
  # A bundle keeps its libraries under base/lib/.
  while IFS= read -r entry; do
    abi="$(sed -E 's#^(base/)?lib/([^/]+)/libapp\.so$#\2#' <<<"$entry")"
    found=1
    unzip -p "$archive" "$entry" > "$tmp/libapp.so"
    got="$(debug_files_build_id "$tmp/libapp.so")"
    want=""
    [[ -f "$symbols/libapp-$abi.debug" ]] && want="$(debug_files_build_id "$symbols/libapp-$abi.debug")"
    if [[ -z "$want" ]]; then
      echo "$(basename "$archive"): $abi's libapp.so (build ID $got) has no saved debug file ($symbols/libapp-$abi.debug)." >&2
      rm -rf "$tmp"
      return 1
    fi
    if [[ "$got" != "$want" ]]; then
      echo "$(basename "$archive"): $abi's libapp.so has build ID $got, but $symbols/libapp-$abi.debug has $want." >&2
      rm -rf "$tmp"
      return 1
    fi
    echo "  $(basename "$archive") $abi: build ID $got matches libapp-$abi.debug"
  done < <(grep -E '^(base/)?lib/[^/]+/libapp\.so$' <<<"$entries")
  rm -rf "$tmp"
  if [[ "$found" == 0 ]]; then
    echo "$(basename "$archive") has no libapp.so." >&2
    return 1
  fi
}

# Checks the Linux bundle's libapp.so ([1]) against debug file [2].
debug_files_check_linux() {
  local so="$1" debug="$2" got want
  got="$(debug_files_build_id "$so")"
  want="$(debug_files_build_id "$debug")"
  if [[ -z "$got" || "$got" != "$want" ]]; then
    echo "$so has build ID ${got:-none}, but $debug has ${want:-none}." >&2
    return 1
  fi
  echo "  libapp.so: build ID $got matches $(basename "$debug")"
}

# Fails when the file list on stdin names a debug file; [1] names the
# package in the message.
debug_files_none_inside() {
  local listing
  listing="$(cat)"
  if grep -E '\.debug$|(^|/)symbols(/|$)' <<<"$listing" >/dev/null; then
    echo "$1 holds a debug file:" >&2
    grep -E '\.debug$|(^|/)symbols(/|$)' <<<"$listing" >&2
    return 1
  fi
  echo "  $1: no debug file inside"
}

# Saves the Flutter engine revision the build used in [1]/engine.version
# (crash-visibility D1): tool/symbolize_event.py downloads that engine's
# published libflutter.so symbols to name native crash frames in the engine.
debug_files_engine() {
  local rev
  rev="$(flutter --version --machine 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["engineRevision"])')"
  if [[ -z "$rev" ]]; then
    echo "The Flutter engine revision couldn't be read." >&2
    return 1
  fi
  echo "$rev" > "$1/engine.version"
  echo "  engine revision $rev saved in $1/engine.version"
}
