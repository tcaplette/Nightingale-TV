# syntax=docker/dockerfile:1.7
# Nightingale TV server: the Linux release of Nightingale TV, run in server
# mode on a virtual display (no screen needed).
#
#   docker build -t nightingale-tv-server .
#
# The app isn't built here: its Linux release file is downloaded from the
# Nightingale TV releases at NTV_VERSION, and checked against the .sha256
# file published next to it. A new version is a new NTV_VERSION. The release
# holds the web admin in web/ next to the app (NTV_WEB_DIR changes where it's
# served from); libsqlite3 holds the user accounts.

ARG NTV_VERSION=1.2.7
ARG NTV_RELEASES=https://github.com/tcaplette/Nightingale-TV/releases/download

# The release, checked and unpacked in a stage of its own: only the app's
# folder goes on to the image, never the downloaded archive. Nightingale TV's
# Google client is for the TV and desktop apps only; the server uses each
# user's own client (docker-youtube), so its file is removed here, and the
# build stops if any copy is left.
FROM ubuntu:24.04 AS release
ARG NTV_VERSION
ARG NTV_RELEASES
ADD ${NTV_RELEASES}/v${NTV_VERSION}/nightingale-tv-linux-x64-${NTV_VERSION}.tar.gz \
    ${NTV_RELEASES}/v${NTV_VERSION}/nightingale-tv-linux-x64-${NTV_VERSION}.tar.gz.sha256 /tmp/release/
RUN cd /tmp/release \
 && sha256sum -c nightingale-tv-linux-x64-${NTV_VERSION}.tar.gz.sha256 \
 && mkdir -p /opt/nightingale-tv \
 && tar -xzf nightingale-tv-linux-x64-${NTV_VERSION}.tar.gz -C /opt/nightingale-tv \
 && rm -rf /opt/nightingale-tv/data/flutter_assets/assets/youtube/client \
           /opt/nightingale-tv/web/assets/assets/youtube/client \
 && if find /opt/nightingale-tv -name 'nightingale-tv-youtube.json' | grep -q .; then \
      echo "Nightingale TV's YouTube client file is in the image" >&2; exit 1; \
    fi

FROM ubuntu:24.04

ARG NTV_VERSION

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ffmpeg libmpv2 libgtk-3-0t64 libwebkit2gtk-4.1-0 libgl1-mesa-dri libegl1 libgl1 libgles2 xvfb \
      libsqlite3-0 tini gosu ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

# Ubuntu's image has a "ubuntu" user on 1000; the app's own user takes that
# id, and the entrypoint moves it to PUID/PGID.
RUN userdel -r ubuntu 2>/dev/null; \
    groupadd -g 1000 ntv \
 && useradd -u 1000 -g 1000 -d /config -M -s /usr/sbin/nologin ntv

COPY --from=release /opt/nightingale-tv /opt/nightingale-tv

COPY entrypoint.sh healthcheck.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# The household lives in /config/com.coffeehauslabs.nightingale_tv/ (with
# the user accounts in nightingale.db) and caches in /config/cache/.
ENV XDG_DATA_HOME=/config \
    XDG_CACHE_HOME=/config/cache \
    XDG_CONFIG_HOME=/config/config \
    HOME=/config \
    DISPLAY=:99 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GSETTINGS_BACKEND=memory \
    NO_AT_BRIDGE=1 \
    PUID=1000 \
    PGID=1000 \
    TZ=UTC \
    NTV_SETUP_PORT=8484

LABEL org.opencontainers.image.title="Nightingale TV server" \
      org.opencontainers.image.version="${NTV_VERSION}"

EXPOSE 8484 5004-5009 8487 1900/udp
VOLUME /config

HEALTHCHECK --interval=30s --start-period=60s --timeout=5s --retries=3 CMD ["/usr/local/bin/healthcheck.sh"]

# tini reaps and forwards signals to the entrypoint, which stops the app
# before the display (entrypoint.sh).
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
