"""Fake tuner for Live TV tests: looping test streams as an M3U playlist with
an XMLTV guide, and as an HDHomeRun device, on port 5104.

Channels (source number, what it is):
  2.1  H.264 720p progressive, AAC        (app M3U: needs its user agent)
  4.1  MPEG-2 1080i interlaced, AC-3
  7.1  H.264 720p with CEA-608 captions   (guide matched by name only)
  9.1  H.264 served as live HLS
  11.1 H.264, not in the guide

Endpoints (URLs use the Host the request came in on):
  /channels.m3u            app playlist (x-tvg-url = gzipped guide), plus a
                           radio entry and an unsupported scheme to be skipped
  /server.m3u              plain playlist for Jellyfin's and Emby's M3U tuner
  /big.m3u?n=500           n channels over the same streams, in groups of 50,
                           with /bigguide.xml.gz (a guide for each)
  /xmltv.xml               48-hour guide from the current hour
  /xmltv.xml.gz            the same, gzipped
  /guide.xml               the same, gzipped under a plain name
  /discover.json, /lineup.json, /lineup_status.json, /auto/v<n>  HDHomeRun
  /stream/<n>.ts, /ua/<n>.ts (needs User-Agent NightingaleFakeTuner/1.0),
  /hls/9.1/index.m3u8, /logo/<n>.png
Test controls:
  /control/status          open streams, each with its user agent
  /control/drop            closes every open stream (a provider drop)
  /control/refuse?code=458 answers stream requests with that status
  /control/tuners?count=2  at most that many streams at once (HDHomeRun
                           answers 503 / error 805, others 458)
  /control/rotate          changes every stream URL in the playlists
  /control/reset           undoes refuse, tuners and rotate
"""

import datetime as dt
import gzip
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse
from xml.sax.saxutils import escape

DATA = os.environ.get("FAKE_TUNER_DATA", "/data")
PORT = int(os.environ.get("FAKE_TUNER_PORT", "5104"))
FONT = "/usr/share/fonts/dejavu/DejaVuSans.ttf"
CLIP_SECONDS = 60
USER_AGENT = "NightingaleFakeTuner/1.0"

# number, name, guide id, guide display name, group, clip
CHANNELS = [
    ("2.1", "Fake H264", "fake21.test", "Fake H264", "Locals", "h264"),
    ("4.1", "Fake MPEG2", "fake41.test", "Fake MPEG2", "Locals", "mpeg2i"),
    ("7.1", "Fake-Captions", None, "fake captions", "Locals", "captions"),
    ("9.1", "Fake HLS", "fake91.test", "Fake HLS", "Streaming", "hls"),
    ("11.1", "Fake No Guide", None, None, "Streaming", "h264b"),
]
GUIDE_IDS = {c[0]: (c[2] or "fake%s.test" % c[0].replace(".", "")) for c in CHANNELS}
COLORS = ["0x1565c0", "0xc62828", "0x2e7d32", "0x6a1b9a", "0xef6c00"]

state_lock = threading.Lock()
state = {"refuse": None, "tuners": 8, "token": 0}
streams = {}  # id -> {"channel", "ua", "proc", "since"}
next_stream = [0]


def run(args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + args, check=True)


def esc_text(s):
    return s.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


def label_filter(text):
    return (
        "drawtext=fontfile=%s:text='%s':fontsize=56:fontcolor=white:box=1:"
        "boxcolor=black@0.6:x=(w-tw)/2:y=h-160,"
        "drawtext=fontfile=%s:text='%%{pts\\:hms}':fontsize=40:fontcolor=yellow:x=40:y=40"
        % (FONT, esc_text(text), FONT)
    )


# ---------------------------------------------------------------- captions

def odd_parity(b):
    return b | 0x80 if bin(b).count("1") % 2 == 0 else b


def cc_pairs():
    """CEA-608 field-1 byte pairs, one per frame: a roll-up line every 2 s."""
    frames = int(CLIP_SECONDS * 30000 / 1001)
    per_line = 60
    pairs = []
    line = 0
    while len(pairs) < frames:
        line += 1
        text = "Fake captions line %d" % line
        # Roll-up 2 rows, carriage return (each control code sent twice).
        out = [(0x14, 0x25), (0x14, 0x25), (0x14, 0x2D), (0x14, 0x2D)]
        chars = [ord(c) for c in text]
        if len(chars) % 2:
            chars.append(0)
        out += [(chars[i], chars[i + 1]) for i in range(0, len(chars), 2)]
        out += [(0, 0)] * (per_line - len(out))
        pairs += out
    return [(odd_parity(a), odd_parity(b)) for a, b in pairs[:frames]]


def ebsp(payload):
    out = bytearray()
    zeros = 0
    for b in payload:
        if zeros >= 2 and b <= 3:
            out.append(3)
            zeros = 0
        out.append(b)
        zeros = zeros + 1 if b == 0 else 0
    return bytes(out)


def cc_sei(pair):
    body = bytes([0xB5, 0x00, 0x31]) + b"GA94" + bytes([0x03, 0x40 | 1, 0xFF, 0xFC, pair[0], pair[1], 0xFF])
    sei = bytes([0x06, 0x04, len(body)]) + body + bytes([0x80])
    return b"\x00\x00\x00\x01" + ebsp(sei[:1]) + ebsp(sei[1:])


def split_nals(data):
    starts = [m.start() for m in re.finditer(b"\x00\x00\x01", data)]
    nals = []
    for i, s in enumerate(starts):
        begin = s - 1 if s > 0 and data[s - 1] == 0 else s
        end = len(data)
        if i + 1 < len(starts):
            n = starts[i + 1]
            end = n - 1 if data[n - 1] == 0 else n
        nals.append(data[begin:end])
    return nals


def inject_captions(src, dst):
    data = open(src, "rb").read()
    pairs = cc_pairs()
    frame = 0
    with open(dst, "wb") as out:
        for nal in split_nals(data):
            header = nal[nal.index(b"\x00\x00\x01") + 3]
            kind = header & 0x1F
            if kind in (1, 5):
                out.write(cc_sei(pairs[frame % len(pairs)]))
                frame += 1
            out.write(nal)


# ---------------------------------------------------------------- media

def make_media():
    os.makedirs(DATA, exist_ok=True)
    tmp = os.path.join(DATA, "tmp")
    os.makedirs(tmp, exist_ok=True)
    d = CLIP_SECONDS

    def clip(name, build):
        out = os.path.join(DATA, name + ".ts")
        if os.path.getsize(out) if os.path.exists(out) else 0:
            return
        print("making", name, flush=True)
        part = out + ".part"
        build(part)
        os.rename(part, out)

    def h264(label, freq):
        def build(out):
            run(["-f", "lavfi", "-i", "testsrc2=s=1280x720:r=30000/1001:d=%d" % d,
                 "-f", "lavfi", "-i", "sine=f=%d:d=%d:sample_rate=48000" % (freq, d),
                 "-vf", label_filter(label),
                 "-c:v", "libx264", "-preset", "veryfast", "-b:v", "3M", "-maxrate", "3M",
                 "-bufsize", "6M", "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
                 "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k", "-f", "mpegts", out])
        return build

    clip("h264", h264("2.1 Fake H264", 440))
    clip("h264b", h264("11.1 Fake No Guide", 660))
    clip("hls_src", h264("9.1 Fake HLS", 550))

    def mpeg2(out):
        run(["-f", "lavfi", "-i", "testsrc2=s=1920x1080:r=60000/1001:d=%d" % d,
             "-f", "lavfi", "-i", "sine=f=330:d=%d:sample_rate=48000" % d,
             "-vf", label_filter("4.1 Fake MPEG2 1080i") + ",tinterlace=mode=interleave_top,setfield=tff",
             "-c:v", "mpeg2video", "-b:v", "8M", "-maxrate", "10M", "-bufsize", "4M",
             "-flags", "+ilme+ildct", "-top", "1", "-g", "30", "-bf", "2",
             "-c:a", "ac3", "-b:a", "384k", "-f", "mpegts", out])
    clip("mpeg2i", mpeg2)

    def captions(out):
        raw = os.path.join(tmp, "captions.h264")
        withcc = os.path.join(tmp, "captions_cc.h264")
        audio = os.path.join(tmp, "captions.m4a")
        run(["-f", "lavfi", "-i", "testsrc2=s=1280x720:r=30000/1001:d=%d" % d,
             "-vf", label_filter("7.1 Fake Captions"),
             "-c:v", "libx264", "-preset", "veryfast", "-b:v", "3M", "-bf", "0",
             "-g", "60", "-keyint_min", "60", "-sc_threshold", "0", "-x264-params", "sliced-threads=0",
             "-threads", "1", "-pix_fmt", "yuv420p", "-f", "h264", raw])
        inject_captions(raw, withcc)
        run(["-f", "lavfi", "-i", "sine=f=770:d=%d:sample_rate=48000" % d, "-c:a", "aac", audio])
        run(["-framerate", "30000/1001", "-f", "h264", "-i", withcc, "-i", audio,
             "-map", "0:v", "-map", "1:a", "-c", "copy", "-f", "mpegts", out])
    clip("captions", captions)

    for i, c in enumerate(CHANNELS):
        logo = os.path.join(DATA, "logo_%s.png" % c[0])
        if not os.path.exists(logo):
            run(["-f", "lavfi", "-i", "color=c=%s:s=256x256" % COLORS[i],
                 "-vf", "drawtext=fontfile=%s:text='%s':fontsize=72:fontcolor=white:x=(w-tw)/2:y=(h-th)/2"
                 % (FONT, esc_text(c[0])), "-frames:v", "1", logo])
    shutil.rmtree(tmp, ignore_errors=True)


def start_hls():
    out = os.path.join("/tmp/hls/9.1")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    subprocess.Popen(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-re", "-stream_loop", "-1",
         "-i", os.path.join(DATA, "hls_src.ts"), "-c", "copy", "-f", "hls",
         "-hls_time", "2", "-hls_list_size", "6", "-hls_flags", "delete_segments+omit_endlist",
         os.path.join(out, "index.m3u8")])


# ---------------------------------------------------------------- guide

SHOWS = {
    "2.1": [("The News", "Local headlines and weather.", "News", 30)],
    "4.1": [("Fake Drama", "A test drama in two acts.", "Drama", 60)],
    "7.1": [("Captioned Hour", "Closed captions on every line.", "Talk", 30),
            ("Caption Talk", "More captions.", "Talk", 60)],
    "9.1": [("Test Movie", "A two-hour test film.", "Movie", 120)],
}


def xmltv_time(t, offset_hours):
    tz = dt.timezone(dt.timedelta(hours=offset_hours))
    s = t.astimezone(tz).strftime("%Y%m%d%H%M%S")
    sign = "+" if offset_hours >= 0 else "-"
    return "%s %s%02d00" % (s, sign, abs(offset_hours))


def guide(host):
    now = dt.datetime.now(dt.timezone.utc)
    start0 = now.replace(minute=0, second=0, microsecond=0) - dt.timedelta(hours=1)
    end = start0 + dt.timedelta(hours=49)
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<!DOCTYPE tv SYSTEM "xmltv.dtd">',
           '<tv generator-info-name="nightingale-fake-tuner">']
    for c in CHANNELS:
        if c[3] is None:
            continue
        out.append('  <channel id="%s">' % GUIDE_IDS[c[0]])
        out.append('    <display-name lang="en">%s</display-name>' % escape(c[3]))
        out.append('    <display-name lang="en">%s</display-name>' % c[0])
        out.append('    <icon src="http://%s/logo/%s.png"/>' % (host, c[0]))
        out.append("  </channel>")
    offsets = {"2.1": 0, "4.1": -4, "7.1": -5, "9.1": 2}
    for c in CHANNELS:
        if c[3] is None:
            continue
        num = c[0]
        t = start0
        n = 0
        while t < end:
            title, desc, cat, mins = SHOWS[num][n % len(SHOWS[num])]
            stop = t + dt.timedelta(minutes=mins)
            off = offsets[num]
            episode = n + 1
            out.append('  <programme start="%s" stop="%s" channel="%s">'
                       % (xmltv_time(t, off), xmltv_time(stop, off), GUIDE_IDS[num]))
            out.append('    <title lang="en">%s</title>' % escape(title))
            out.append('    <title lang="fr">%s (fr)</title>' % escape(title))
            if cat != "Movie":
                out.append('    <sub-title lang="en">Part %d</sub-title>' % episode)
            out.append('    <desc lang="en">%s Airing %d.</desc>' % (escape(desc), episode))
            out.append('    <category lang="en">%s</category>' % cat)
            if cat == "Movie":
                out.append("    <date>1999</date>")
                out.append('    <rating system="MPAA"><value>PG</value></rating>')
            elif num == "7.1":
                out.append('    <episode-num system="onscreen">S1E%d</episode-num>' % episode)
            else:
                out.append('    <episode-num system="xmltv_ns">2.%d.</episode-num>' % (episode - 1))
                out.append('    <rating system="VCHIP"><value>TV-PG</value></rating>')
            if n % 3 == 0:
                out.append("    <new/>")
            else:
                out.append("    <previously-shown/>")
            out.append("  </programme>")
            t = stop
            n += 1
    out.append("</tv>")
    return ("\n".join(out) + "\n").encode()


# ---------------------------------------------------------------- playlists

def playlist(host, for_server):
    token = state["token"]
    lines = ['#EXTM3U x-tvg-url="http://%s/xmltv.xml.gz"' % host] if not for_server else ["#EXTM3U"]
    for c in CHANNELS:
        num, name, gid, _, group, clip = c
        attrs = []
        if gid:
            attrs.append('tvg-id="%s"' % gid)
        attrs.append('tvg-name="%s"' % name)
        attrs.append('tvg-logo="http://%s/logo/%s.png"' % (host, num))
        attrs.append('tvg-chno="%s"' % num)
        attrs.append('group-title="%s"' % group)
        lines.append("#EXTINF:-1 %s,%s" % (" ".join(attrs), name))
        if clip == "hls":
            url = "http://%s/hls/9.1/index.m3u8" % host
        elif num == "2.1" and not for_server:
            lines.append("#EXTVLCOPT:http-user-agent=%s" % USER_AGENT)
            url = "http://%s/ua/%s.ts" % (host, num)
        else:
            url = "http://%s/stream/%s.ts" % (host, num)
        if token and clip != "hls":
            url += "?t=%d" % token
        lines.append(url)
    if not for_server:
        lines += ['#EXTINF:-1 tvg-id="radio.test" radio="true",Fake Radio',
                  "http://%s/stream/2.1.ts" % host,
                  '#EXTINF:-1 tvg-id="mms.test",Fake MMS', "mms://%s/stream" % host]
    return ("\r\n".join(lines) + "\r\n").encode()


def big_playlist(host, n):
    lines = ['#EXTM3U x-tvg-url="http://%s/bigguide.xml.gz?n=%d"' % (host, n)]
    plain = [c for c in CHANNELS if c[5] not in ("hls", "mpeg2i")]
    for i in range(n):
        c = plain[i % len(plain)]
        lines.append('#EXTINF:-1 tvg-id="big%d.test" tvg-chno="%d" group-title="Group %02d",Big %d'
                     % (i, 1000 + i, i // 50, i))
        lines.append("http://%s/stream/%s.ts" % (host, c[0]))
    return ("\n".join(lines) + "\n").encode()


def big_guide(n):
    now = dt.datetime.now(dt.timezone.utc)
    start0 = now.replace(minute=0, second=0, microsecond=0) - dt.timedelta(hours=1)
    out = ['<?xml version="1.0" encoding="UTF-8"?>', "<tv>"]
    for i in range(n):
        out.append('<channel id="big%d.test"><display-name>Big %d</display-name></channel>' % (i, i))
    for i in range(n):
        for h in range(49):
            t = start0 + dt.timedelta(hours=h)
            out.append('<programme start="%s" stop="%s" channel="big%d.test"><title>Big show %d</title>'
                       '<desc>Hour %d on channel %d.</desc></programme>'
                       % (xmltv_time(t, 0), xmltv_time(t + dt.timedelta(hours=1), 0), i, h, h, i))
    out.append("</tv>")
    return ("\n".join(out) + "\n").encode()


def discover(host):
    return json.dumps({
        "FriendlyName": "Nightingale Fake Tuner", "ModelNumber": "HDHR5-4US",
        "FirmwareName": "hdhomerun5_atsc", "FirmwareVersion": "20240101",
        "DeviceID": "10ABCDEF", "DeviceAuth": "fake", "TunerCount": state["tuners"],
        "BaseURL": "http://%s" % host, "LineupURL": "http://%s/lineup.json" % host,
    }).encode()


def lineup(host):
    return json.dumps([
        {"GuideNumber": c[0], "GuideName": c[1], "VideoCodec": "MPEG2" if c[5] == "mpeg2i" else "H264",
         "AudioCodec": "AC3" if c[5] == "mpeg2i" else "AAC", "HD": 1,
         "URL": "http://%s/auto/v%s" % (host, c[0])}
        for c in CHANNELS if c[5] != "hls"]).encode()


# ---------------------------------------------------------------- server

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        print("%s %s" % (self.address_string(), fmt % args), flush=True)

    def host(self):
        return self.headers.get("Host") or "127.0.0.1:%d" % PORT

    def send(self, code, body, ctype="application/octet-stream", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        url = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        p = url.path
        host = self.host()
        if p == "/channels.m3u":
            return self.send(200, playlist(host, False), "audio/x-mpegurl")
        if p == "/big.m3u":
            return self.send(200, big_playlist(host, int(q.get("n", "500"))), "audio/x-mpegurl")
        if p == "/bigguide.xml.gz":
            return self.send(200, gzip.compress(big_guide(int(q.get("n", "500")))), "application/gzip")
        if p == "/server.m3u":
            return self.send(200, playlist(host, True), "audio/x-mpegurl")
        if p == "/xmltv.xml":
            return self.send(200, guide(host), "application/xml")
        if p in ("/xmltv.xml.gz", "/guide.xml"):
            return self.send(200, gzip.compress(guide(host)),
                             "application/gzip" if p.endswith(".gz") else "application/xml")
        if p == "/discover.json":
            return self.send(200, discover(host), "application/json")
        if p == "/lineup.json":
            return self.send(200, lineup(host), "application/json")
        if p == "/lineup_status.json":
            return self.send(200, json.dumps({"ScanInProgress": 0, "ScanPossible": 1, "Source": "Antenna",
                                              "SourceList": ["Antenna"]}).encode(), "application/json")
        m = re.fullmatch(r"/logo/([\d.]+)\.png", p)
        if m and os.path.exists(os.path.join(DATA, "logo_%s.png" % m.group(1))):
            return self.send(200, open(os.path.join(DATA, "logo_%s.png" % m.group(1)), "rb").read(), "image/png")
        if p.startswith("/hls/"):
            f = os.path.normpath(os.path.join("/tmp", p.lstrip("/")))
            if f.startswith("/tmp/hls/") and os.path.isfile(f):
                ctype = "application/vnd.apple.mpegurl" if f.endswith(".m3u8") else "video/mp2t"
                return self.send(200, open(f, "rb").read(), ctype, {"Cache-Control": "no-cache"})
            return self.send(404, b"not found", "text/plain")
        m = re.fullmatch(r"/(stream|ua)/([\d.]+)\.ts|/auto/v([\d.]+)", p)
        if m:
            return self.stream(m.group(2) or m.group(3), m.group(1) or "auto")
        if p.startswith("/control/"):
            return self.control(p[len("/control/"):], q)
        self.send(404, b"not found", "text/plain")

    def control(self, what, q):
        with state_lock:
            if what == "refuse":
                state["refuse"] = int(q.get("code", "458"))
            elif what == "tuners":
                state["tuners"] = int(q.get("count", "2"))
            elif what == "rotate":
                state["token"] += 1
            elif what == "reset":
                state.update(refuse=None, tuners=8, token=0)
            elif what == "drop":
                for s in streams.values():
                    s["proc"].kill()
            elif what != "status":
                return self.send(404, b"unknown control", "text/plain")
            body = json.dumps({
                "refuse": state["refuse"], "tuners": state["tuners"], "token": state["token"],
                "streams": [{"id": k, "channel": s["channel"], "ua": s["ua"], "since": s["since"]}
                            for k, s in streams.items()],
            }).encode()
        self.send(200, body, "application/json")

    def stream(self, num, kind):
        chan = next((c for c in CHANNELS if c[0] == num and c[5] != "hls"), None)
        if chan is None:
            return self.send(404, b"no such channel", "text/plain")
        ua = self.headers.get("User-Agent", "")
        if kind == "ua" and ua != USER_AGENT:
            return self.send(403, b"wrong user agent", "text/plain")
        with state_lock:
            if state["refuse"]:
                return self.send(state["refuse"], b"refused", "text/plain")
            if len(streams) >= state["tuners"]:
                if kind == "auto":
                    return self.send(503, b"All tuners in use", "text/plain",
                                     {"X-HDHomeRun-Error": "805 All Tuners In Use"})
                return self.send(458, b"connection limit", "text/plain")
            if self.command == "HEAD":
                return self.send(200, b"", "video/mp2t")
            proc = subprocess.Popen(
                ["ffmpeg", "-hide_banner", "-loglevel", "error", "-re", "-stream_loop", "-1",
                 "-i", os.path.join(DATA, chan[5] + ".ts"), "-map", "0", "-c", "copy",
                 "-f", "mpegts", "pipe:1"], stdout=subprocess.PIPE)
            next_stream[0] += 1
            sid = next_stream[0]
            streams[sid] = {"channel": num, "ua": ua, "proc": proc, "since": time.time()}
        print("stream %d open: %s (%s) ua=%r" % (sid, num, kind, ua), flush=True)
        try:
            self.send_response(200)
            self.send_header("Content-Type", "video/mp2t")
            self.send_header("Connection", "close")
            self.end_headers()
            while True:
                chunk = proc.stdout.read(65536)
                if not chunk:
                    break
                self.wfile.write(chunk)
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            proc.kill()
            proc.wait()
            with state_lock:
                streams.pop(sid, None)
            self.close_connection = True
            print("stream %d closed" % sid, flush=True)


def main():
    make_media()
    start_hls()
    signal.signal(signal.SIGTERM, lambda *_: os._exit(0))
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.daemon_threads = True
    print("fake tuner on port %d" % PORT, flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
