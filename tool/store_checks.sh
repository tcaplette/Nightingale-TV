# Checks shared by tool/build_apk.sh and tool/build_bundle.sh (play-unlock
# D7, D8). Sourced, not run: each function exits the build on a failure.

# The stand-in store and the trial offset are for testing only. A release
# built with either would lock (or unlock) installs that shouldn't be, so the
# build stops before it starts when error_reporting.env sets one.
store_refuse_test_defines() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0
  local found
  found="$(grep -E '^[[:space:]]*(NTV_FAKE_STORE|NTV_TRIAL_OFFSET_DAYS)[[:space:]]*=' "$env_file" | sed 's/=.*//' | tr -d ' \t' | sort -u | paste -sd, -)" || true
  if [[ -n "$found" ]]; then
    echo "$env_file sets $found, which is for testing only (the stand-in store and the trial offset)." >&2
    echo "Remove it from $env_file before building a release." >&2
    exit 1
  fi
}

# The free APKs carry no Play Billing: neither its permission nor its classes.
store_check_apk_has_no_billing() {
  local aapt2="$1" apk="$2"
  if "$aapt2" dump permissions "$apk" | grep -q 'com.android.vending.BILLING'; then
    echo "$apk declares com.android.vending.BILLING; free APKs must not (play-unlock)." >&2
    exit 1
  fi
  if unzip -Z1 "$apk" 'classes*.dex' >/dev/null 2>&1 &&
     unzip -p "$apk" 'classes*.dex' | grep -aq 'Lcom/android/billingclient/'; then
    echo "$apk contains the Play Billing Library's classes; free APKs must not (play-unlock)." >&2
    exit 1
  fi
}

# bundletool, pinned and checksummed: the one on PATH, or this release
# fetched once into build/tools/.
BUNDLETOOL_VERSION=1.18.3
BUNDLETOOL_SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29

store_bundletool() {
  if command -v bundletool >/dev/null 2>&1; then
    bundletool "$@"
    return
  fi
  local jar="$ROOT/build/tools/bundletool-all-$BUNDLETOOL_VERSION.jar"
  if [[ ! -f "$jar" ]] || ! echo "$BUNDLETOOL_SHA256  $jar" | sha256sum -c --status; then
    mkdir -p "$(dirname "$jar")"
    echo "Fetching bundletool $BUNDLETOOL_VERSION into build/tools/ ..." >&2
    curl -fsSL -o "$jar.part" \
      "https://github.com/google/bundletool/releases/download/$BUNDLETOOL_VERSION/bundletool-all-$BUNDLETOOL_VERSION.jar"
    if ! echo "$BUNDLETOOL_SHA256  $jar.part" | sha256sum -c --status; then
      rm -f "$jar.part"
      echo "The downloaded bundletool doesn't match its pinned checksum; not using it." >&2
      exit 1
    fi
    mv "$jar.part" "$jar"
  fi
  java -jar "$jar" "$@"
}

# The Play bundle carries Play Billing, the official id and the pubspec's
# version code.
store_check_bundle() {
  local aab="$1" version_code="$2"
  local manifest
  manifest="$(store_bundletool dump manifest --bundle="$aab")"
  if ! grep -q 'android:name="com.android.vending.BILLING"' <<<"$manifest"; then
    echo "$aab doesn't declare com.android.vending.BILLING; the Play bundle must be the play flavor." >&2
    exit 1
  fi
  if ! grep -q 'package="com.coffeehauslabs.nightingale_tv"' <<<"$manifest"; then
    echo "$aab doesn't have the id com.coffeehauslabs.nightingale_tv." >&2
    exit 1
  fi
  if ! grep -q "android:versionCode=\"$version_code\"" <<<"$manifest"; then
    echo "$aab doesn't have the version code $version_code from pubspec.yaml." >&2
    exit 1
  fi
}
