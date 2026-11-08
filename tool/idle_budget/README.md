# Idle budget checks

The idle budgets (openspec `idle-power`) and the tools that measure them.

| Platform | Idle state | Budget |
|---|---|---|
| Server (Docker, Linux `--server`) | no viewer, 20 s after the last one left | 0 stream ffmpeg; app + Xvfb under 1% of one core over 5 min |
| Linux desktop | asleep | no stream on the media server, no mpv decoding, app under 1% |
| Android TV / phone | asleep, or the app in the background | no stream on the media server, no decoder open, app under 1% |

One core is 100%: CPU ticks over wall time.

## Results

Server check (`server_check.sh`), the Linux bundle with the seed config. The window is 300 s.

| Run | 1 up | 2 HEAD ×12 | 3 viewer, then 20 s | 4 idle, 300 s | 5 stop |
|---|---|---|---|---|---|
| before (HEAD, 2026-11-07) | pass | **FAIL**: 2 stream ffmpeg (muxer + encode) started by HEAD | pass: 11.3 MB in 10 s, 0 stream after | pass: app 0.01%, Xvfb 0.00%, no background work | pass |
| after, Linux bundle (2026-11-07) | pass | pass: 12 × 200, 0 stream | pass: 4.8 MB in 10 s, 0 stream after | pass: app 0.00%, Xvfb 0.00%, no background work | pass |
| after, Docker image (local 24.04 release, 2026-11-07) | pass | pass: 12 × 200, 0 stream | pass: 183 KB in 10 s (software encode, tuning card first), 0 stream after | pass: app 0.00%, Xvfb 0.00%, no background work | pass: container gone, nothing left |

Clients, asleep (measured 5 min, starting 15 s after sleep, with a diagnostics build and the still-watching time shortened to 1–2 min):

| Platform | Prompt, OK, sleep | Server session | Decoding | App CPU |
|---|---|---|---|---|
| Linux desktop (Xvfb, 2026-11-07), first run | prompt at 2:00, OK closed it, next at 2:00, slept 60 s later, stopped after the 10 s fade | none playing | mpv idle | **1.29%: FAIL**. The diagnostics samplers kept polling mpv every 250 ms and 1 s with nothing on |
| Linux desktop, after the fix (samplers stand down with no channel on) | as above | none playing | mpv idle | 0.10%: pass |
| Android TV emulator (TV_1080p_x86_64), asleep | prompt at 2:00, slept 60 s later, stopped after the fade; D-pad OK and the uhid mouse each closed it with nothing behind reacting (after the pointer-settle fix) | none playing | 0 codecs held | 0.09%: pass |
| Android TV emulator, app in the background (Home) | | none playing | 0 codecs held | 0.02%: pass |
| Android phone emulator (Pixel_8), asleep | portrait player: a tap closed the prompt without opening the controls; with no answer it slept 60 s later and stopped after the fade | none playing | 0 codecs held | 0.18%: pass |
| Android phone emulator, app in the background (Home) | | none playing | 0 codecs held | 0.03%: pass |

## The tools

- `measure.sh <pid> <seconds> [--xvfb <pid>] [--no-cpu]`: the app's own CPU (and its virtual display's), and every ffmpeg under it, classed by its arguments as `stream`, `analysis` or `card` (card chunks and the encoder check). Pass/fail is on the app's CPU (app + Xvfb with `--xvfb`) and the stream count. Analysis and card work is printed on the `background` line and never decides it. Any ffmpeg it can't place counts as a stream. Exit 0 = within budget, 1 = over, 2 = couldn't measure.
- `measure.sh --adb <package> <seconds>`: the same for an Android app through adb (`ADB` picks the adb binary), plus the codecs it holds, from `dumpsys media.resource_manager` (a client whose newest event is an add is open).
- `test_classify.sh`: the classifier against the saved command lines in `testdata/argv.txt`. `test/idle_budget_classify_test.dart` checks the live `EncodeArgs` and `FfmpegRunner` lines in the unit suite.
- `server_check.sh --bundle <dir> | --docker <image>`: the server check (design D4), one line per step, exiting at the first failure. `KEEP_GOING=1` runs every step anyway (for a "before" row). `IDLE_WINDOW` changes step 4's 300 s, and `EXPORT_PORT` changes the seed profile's tuner port (5004).

## Running the server check

The Linux bundle:

```
flutter build linux --release
XVFB=/path/to/Xvfb tool/idle_budget/server_check.sh --bundle build/linux/x64/release/bundle
```

It runs the app in server mode on its own Xvfb (`:77`, or `XVFB_DISPLAY`) with a copy of `seed/` as its data dirs, laid out like the image's `/config`. Xvfb isn't installed on the dev machine. Get it with `apt-get download xvfb` and `dpkg-deb -x` into a scratch folder.

The Docker image: build it from a local release (an Ubuntu 24.04 build, as the release workflow makes it), then run the check:

```
tool/build_linux_release.sh            # in the ntv-linux-build:24.04 container
(cd dist && python3 -m http.server 8765 --bind 127.0.0.1) &
sg docker -c "docker build --network host --build-arg NTV_RELEASES=http://127.0.0.1:8765 \
  --build-arg NTV_VERSION=<version> -t nightingale-tv-server:idle-check docker"
tool/idle_budget/server_check.sh --docker nightingale-tv-server:idle-check
```

`NTV_RELEASES` must serve `v<version>/nightingale-tv-linux-x64-<version>.tar.gz` and its `.sha256`. The container maps 8484 and 5004–5009, as `docker-compose.bridge.yml` does. It measures the container's processes from the host (`docker top`).

## The seed config

`seed/` is git-ignored: it holds the test server's token. It's a server config with the first admin (`admin`, password `idle check admin pass` in `test-data.md`) and one profile, "Idle check", signed in to the test server from `test-data.md` and exported on port 5004.

`server_check.sh` fails at step 1 with "the seed config isn't signed in" when the token has gone stale. Make it again:

```
PLAYWRIGHT_MODULES=/path/with/node_modules XVFB=/path/to/Xvfb tool/idle_budget/make_seed.sh
```

This starts the bundle with fresh data dirs, reads the setup link from its log, and runs `make_seed.js` in the Playwright container (`mcr.microsoft.com/playwright:v1.56.1-noble`) on the `ntv-offline` network. The script sets the admin's password, starts fresh with one profile, signs it in, and waits until its lineup is exported. The container reaches the host at 192.168.77.1, so the host firewall must let traffic from that bridge through. `PLAYWRIGHT_MODULES` is a folder where `npm i playwright@1.56.1` was run.
