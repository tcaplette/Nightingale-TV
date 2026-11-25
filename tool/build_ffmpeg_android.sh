#!/usr/bin/env bash
# Builds FFmpeg for Android (smb-conversion): the programs ffmpeg and
# ffprobe as libffmpeg.so and libffprobe.so, and their libraries, for
# arm64-v8a, armeabi-v7a and x86_64, into android/app/src/main/jniLibs
# (git-ignored). Android runs programs only from an app's native library
# folder, and only files named lib*.so are put there, hence the names. The
# app starts them with LD_LIBRARY_PATH set to that folder.
#
#   tool/build_ffmpeg_android.sh          build what is missing
#   tool/build_ffmpeg_android.sh --force  build everything again
#   tool/build_ffmpeg_android.sh --check  say whether it is built (exit 1: no)
#
# Sources are pinned by checksum: FFmpeg with libx264 (GPL), zimg (HDR
# tone-mapping) and dav1d (AV1). Only what reading and converting video files
# needs is built in. Everything is 16 KB page aligned.
#
# Needs the Android NDK ($ANDROID_NDK, or the version below under the SDK),
# make, ninja, python3 and curl. nasm is built when it isn't installed, and
# meson is put in its own Python environment. Work happens in
# ~/.cache/nightingale-ffmpeg-android ($NTV_FFMPEG_WORK).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/android/app/src/main/jniLibs"
WORK="${NTV_FFMPEG_WORK:-$HOME/.cache/nightingale-ffmpeg-android}"
NDK_VERSION=28.2.13676358
API=24
ABIS=(arm64-v8a armeabi-v7a x86_64)
JOBS="${JOBS:-$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))}"
FORCE=""

FFMPEG=8.0.3
SOURCES=(
  "ffmpeg-$FFMPEG.tar.xz https://ffmpeg.org/releases/ffmpeg-$FFMPEG.tar.xz 6136812ea6d4e68bdba27e33c2a94382711cdf4f8602ffef056ff792bd6f9818"
  "x264.tar.gz https://code.videolan.org/videolan/x264/-/archive/b35605ace3ddf7c1a5d67a2eb553f034aef41d55/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz cd71a7515b0e9a012e1ac9b1f8415bebcaf6fc97d4db32286642ac4c0fbe24f9"
  "zimg.tar.gz https://github.com/sekrit-twc/zimg/archive/dd4c4dff3ce6a2877bd6ba57c1be99759b9cb2da.tar.gz 3196e00c51d9031402a053a4195d48f2d09050a09a529f459dfbf3719d9265b4"
  "dav1d-1.5.1.tar.xz https://downloads.videolan.org/pub/videolan/dav1d/1.5.1/dav1d-1.5.1.tar.xz 401813f1f89fa8fd4295805aa5284d9aed9bc7fc1fdbe554af4292f64cbabe21"
  "nasm-2.16.03.tar.xz https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.xz 1412a1c760bbd05db026b6c0d1657affd6631cd0a63cddb6f73cc6d4aa616148"
)
MESON=1.9.1

# What was built: this script's own contents, so a change builds again.
STAMP="$(sha256sum "$0" | cut -c1-16)"
built() { [[ -f "$OUT/$1/libffmpeg.so" && -f "$OUT/$1/libffprobe.so" && "$(cat "$OUT/$1/.ffmpeg" 2>/dev/null)" == "$STAMP" ]]; }

case "${1:-}" in
  --check)
    for abi in "${ABIS[@]}"; do built "$abi" || { echo "FFmpeg for Android isn't built ($abi)."; exit 1; }; done
    exit 0 ;;
  --force) FORCE=1 ;;
  "") ;;
  *) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

todo=()
for abi in "${ABIS[@]}"; do [[ -z "$FORCE" ]] && built "$abi" || todo+=("$abi"); done
if [[ ${#todo[@]} -eq 0 ]]; then echo "FFmpeg for Android is built."; exit 0; fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
NDK="${ANDROID_NDK:-$SDK/ndk/$NDK_VERSION}"
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
[[ -x "$TC/bin/clang" ]] || { echo "No Android NDK at $NDK (set ANDROID_NDK)." >&2; exit 1; }
for t in make ninja python3 curl pkg-config; do command -v "$t" >/dev/null || { echo "$t is needed." >&2; exit 1; }; done

mkdir -p "$WORK/dl" "$WORK/src" "$WORK/tools"
for s in "${SOURCES[@]}"; do
  read -r name url sum <<<"$s"
  if ! echo "$sum  $WORK/dl/$name" | sha256sum -c --quiet 2>/dev/null; then
    echo "Downloading $name"
    curl -fsSL -o "$WORK/dl/$name.part" "$url"
    echo "$sum  $WORK/dl/$name.part" | sha256sum -c --quiet
    mv "$WORK/dl/$name.part" "$WORK/dl/$name"
  fi
  dir="$WORK/src/${name%.tar.*}"
  if [[ ! -d "$dir" ]]; then
    part="$(mktemp -d "$WORK/src/unpack.XXXXXX")"
    tar xf "$WORK/dl/$name" -C "$part" --strip-components=1
    mv "$part" "$dir"
  fi
done

export PATH="$WORK/tools/bin:$PATH"
if ! command -v nasm >/dev/null; then
  echo "Building nasm"
  (cd "$WORK/src/nasm-2.16.03" && ./configure --prefix="$WORK/tools" >/dev/null && make -j"$JOBS" >/dev/null && make install >/dev/null)
fi
if [[ ! -x "$WORK/tools/meson/bin/meson" ]]; then
  python3 -m venv "$WORK/tools/meson"
  "$WORK/tools/meson/bin/pip" -q install "meson==$MESON"
fi

build() {
  local abi="$1" arch cpu triple cc ff_asm=() dav1d_cpu
  case "$abi" in
    arm64-v8a) arch=aarch64 cpu=armv8-a triple=aarch64-linux-android cc=aarch64-linux-android dav1d_cpu=aarch64 ;;
    armeabi-v7a) arch=arm cpu=armv7-a triple=arm-linux-androideabi cc=armv7a-linux-androideabi dav1d_cpu=arm ff_asm=(--enable-neon --enable-thumb) ;;
    x86_64) arch=x86_64 cpu=x86-64 triple=x86_64-linux-android cc=x86_64-linux-android dav1d_cpu=x86_64 ;;
  esac
  # A fresh folder for each build, so nothing left from another one counts.
  mkdir -p "$WORK/build"
  local B P
  B="$(mktemp -d "$WORK/build/$abi.XXXXXX")"
  P="$B/prefix"
  mkdir -p "$B/x264" "$B/zimg" "$B/ffmpeg" "$P/lib/pkgconfig" "$P/include"
  local CC="$TC/bin/$cc$API-clang" CXX="$TC/bin/$cc$API-clang++" PAGE="-Wl,-z,max-page-size=16384"

  echo "$abi: x264"
  (cd "$B/x264"
   export CC AR="$TC/bin/llvm-ar" RANLIB="$TC/bin/llvm-ranlib" STRIP="$TC/bin/llvm-strip" STRINGS="$TC/bin/llvm-strings"
   # x264's x86 assembly goes through nasm, ARM's through clang.
   if [[ "$abi" == x86_64 ]]; then export AS=nasm; else export AS="$CC"; fi
   "$WORK/src/x264/configure" --prefix="$P" --host="$triple" --cross-prefix="$TC/bin/llvm-" --sysroot="$TC/sysroot" \
     --enable-static --enable-pic --disable-cli --disable-opencl --bit-depth=8 \
     --extra-cflags="-O3" >configure.log 2>&1 || { tail -20 configure.log; exit 1; }
   make -j"$JOBS" >make.log 2>&1 || { tail -20 make.log; exit 1; }
   make install-lib-static >/dev/null)

  echo "$abi: zimg"
  (cd "$B/zimg"
   # Its own build is autotools; its sources need nothing from it. ARM's
   # NEON code is for 64-bit only.
   src="$WORK/src/zimg/src/zimg"
   flags=(-std=c++14 -O2 -fPIC -fvisibility=hidden -I"$src" -DNDEBUG)
   mapfile -t files < <(find "$src" -name '*.cpp' -not -path '*/x86/*' -not -path '*/arm/*')
   if [[ "$abi" == arm64-v8a ]]; then
     flags+=(-DZIMG_ARM)
     mapfile -t -O "${#files[@]}" files < <(find "$src" -path '*/arm/*' -name '*.cpp')
   fi
   printf '%s\n' "${files[@]}" | xargs -P "$JOBS" -I{} sh -c 'f="$1"; shift; "$@" -c "$f" -o "$(echo "$f" | cksum | cut -d" " -f1).o"' _ {} "$CXX" "${flags[@]}"
   "$TC/bin/llvm-ar" rcs "$P/lib/libzimg.a" ./*.o
   cp "$src/api/zimg.h" "$P/include/")
  cat > "$P/lib/pkgconfig/zimg.pc" <<PC
prefix=$P
Name: zimg
Description: zimg
Version: 3.0.4
Libs: -L\${prefix}/lib -lzimg -lc++_static -lc++abi -lm
Cflags: -I\${prefix}/include
PC

  echo "$abi: dav1d"
  cat > "$B/cross.txt" <<CROSS
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$TC/bin/llvm-ar'
strip = '$TC/bin/llvm-strip'
nasm = '$(command -v nasm)'
[host_machine]
system = 'android'
cpu_family = '$dav1d_cpu'
cpu = '$cpu'
endian = 'little'
CROSS
  "$WORK/tools/meson/bin/meson" setup "$B/dav1d" "$WORK/src/dav1d-1.5.1" --cross-file "$B/cross.txt" --prefix "$P" --libdir lib \
    --default-library static --buildtype release -Denable_tools=false -Denable_tests=false >"$B/dav1d.log" 2>&1 || { tail -20 "$B/dav1d.log"; exit 1; }
  ninja -C "$B/dav1d" -j "$JOBS" install >>"$B/dav1d.log" 2>&1 || { tail -20 "$B/dav1d.log"; exit 1; }

  echo "$abi: FFmpeg"
  (cd "$B/ffmpeg"
   export PKG_CONFIG_LIBDIR="$P/lib/pkgconfig"
   "$WORK/src/ffmpeg-$FFMPEG/configure" --prefix="$P" --target-os=android --arch="$arch" --cpu="$cpu" \
     --enable-cross-compile --sysroot="$TC/sysroot" --cc="$CC" --cxx="$CXX" --ar="$TC/bin/llvm-ar" --nm="$TC/bin/llvm-nm" \
     --ranlib="$TC/bin/llvm-ranlib" --strip="$TC/bin/llvm-strip" --pkg-config=pkg-config --pkg-config-flags=--static \
     --extra-cflags="-O2 -fPIC -I$P/include" --extra-ldflags="-L$P/lib $PAGE" --extra-ldexeflags="$PAGE" \
     --enable-gpl --enable-shared --disable-static --disable-debug --disable-doc --disable-ffplay --disable-avdevice \
     --disable-autodetect --enable-zlib --enable-mediacodec --enable-jni \
     --enable-libx264 --enable-libzimg --enable-libdav1d "${ff_asm[@]}" \
     --disable-everything --enable-parsers --enable-protocol=file,pipe,http,tcp \
     --enable-demuxer=aac,ac3,aiff,ape,asf,asf_o,ass,avi,caf,concat,data,dts,dtshd,dv,eac3,flac,flv,gif,gxf,h264,hevc,ivf,live_flv,lrc,m4v,matroska,mjpeg,mlp,mov,mp3,mpegps,mpegts,mpegvideo,mxf,nsv,nut,nuv,obu,ogg,rawvideo,rm,srt,sup,truehd,tta,vc1,vobsub,wav,webvtt,wtv,wv,yuv4mpegpipe \
     --enable-muxer=ass,image2pipe,matroska,mjpeg,mp4,mpegts,null,srt,webvtt \
     --enable-decoder=aac,aac_latm,ac3,adpcm_ima_qt,adpcm_ima_wav,adpcm_ms,adpcm_swf,adpcm_yamaha,alac,amrnb,amrwb,ape,ass,atrac1,atrac3,atrac3p,cinepak,cook,dca,dnxhd,dvbsub,dvdsub,dvvideo,eac3,ffv1,flac,flashsv,flv,gif,gsm,gsm_ms,h261,h263,h263i,h264,hevc,huffyuv,indeo2,indeo3,indeo4,indeo5,libdav1d,mjpeg,mlp,movtext,mp1,mp2,mp3,mpeg1video,mpeg2video,mpeg4,mpegvideo,mss1,mss2,msmpeg4v1,msmpeg4v2,msmpeg4v3,msvideo1,nellymoser,nuv,opus,pcm_alaw,pcm_bluray,pcm_dvd,pcm_f32le,pcm_mulaw,pcm_s16be,pcm_s16le,pcm_s24be,pcm_s24le,pcm_s32le,pcm_u8,pgssub,png,prores,qdm2,qdmc,qtrle,ra_144,ra_288,rawvideo,rpza,rv10,rv20,rv30,rv40,sipr,speex,srt,ssa,subrip,svq1,svq3,text,theora,truehd,tta,vc1,vc1image,vorbis,vp3,vp5,vp6,vp6a,vp6f,vp7,vp8,vp9,wavpack,webvtt,wmalossless,wmapro,wmav1,wmav2,wmavoice,wmv1,wmv2,wmv3,wmv3image,wrapped_avframe,xsub \
     --enable-encoder=aac,ass,h264_mediacodec,libx264,mjpeg,pcm_s16le,srt,ssa,subrip,webvtt,wrapped_avframe \
     --enable-bsf=aac_adtstoasc,av1_frame_merge,dca_core,dump_extra,extract_extradata,h264_metadata,h264_mp4toannexb,hevc_metadata,hevc_mp4toannexb,mpeg4_unpack_bframes,null,setts,vc1_asftorcv \
     --enable-filter=aformat,anull,aresample,asetpts,atrim,bwdif,crop,format,fps,hflip,null,overlay,pad,pan,scale,setparams,setpts,setsar,tonemap,transpose,trim,vflip,volume,yadif,zscale >configure.log 2>&1 || { tail -5 configure.log; tail -30 ffbuild/config.log; exit 1; }
   make -j"$JOBS" >make.log 2>&1 || { grep -E 'error|Error' make.log | head -20; exit 1; }
   make install >/dev/null 2>&1)

  mkdir -p "$OUT/$abi"
  local lib program f
  for lib in avcodec avformat avfilter avutil swscale swresample; do
    [[ -f "$P/lib/lib$lib.so" ]] && "$TC/bin/llvm-strip" -o "$OUT/$abi/lib$lib.so" "$P/lib/lib$lib.so"
  done
  for program in ffmpeg ffprobe; do
    "$TC/bin/llvm-strip" -o "$OUT/$abi/lib$program.so" "$P/bin/$program"
  done
  # Everything must load on devices with 16 KB pages.
  for f in "$OUT/$abi"/lib*.so; do
    if ! "$TC/bin/llvm-readelf" -lW "$f" | python3 -c 'import sys; sys.exit(any(l.split()[0] == "LOAD" and int(l.split()[-1], 16) < 16384 for l in sys.stdin if l.split()))'; then
      echo "$f isn't 16 KB aligned." >&2
      exit 1
    fi
  done
  echo "$STAMP" > "$OUT/$abi/.ffmpeg"
  echo "$abi: $(du -ch "$OUT/$abi"/*.so | tail -1 | cut -f1) (build files in $B)"
}

for abi in "${todo[@]}"; do build "$abi"; done
