# Nightingale TV

Nightingale TV turns your Jellyfin library into always-on cable TV channels, with a program guide, for a Linux PC hooked up to a TV, an Android TV (Google TV, Fire TV and other Android TV boxes), or an Android phone or tablet. Like real TV, every channel is always mid-broadcast. You tune in to whatever is on, flip channels, and check the guide to see what's coming up.

It's inspired by NostalgiaTV for Android. It's built for the couch, so everything works with a keyboard, a mouse, an air mouse, a TV remote, a touchscreen, or your phone.

![The program guide, with a programming block on channel 2](docs/screenshots/guide.png)

## Features

- **Channels made for you.** The app builds a lineup from your library: an all-shows channel, genre channels (comedy, kids, sci-fi…), marathon channels for your biggest shows, and movie channels. You can rename, renumber, hide or favorite any channel, and give it a built-in icon, a station badge, a show logo or your own image.
- **Always on the air.** Channels run on the clock, so you join a show mid-episode, just like flipping to it on cable.
- **Program guide.** A scrolling cable-style grid with a live preview window. Near the end of each show, an "Up next" card says what's on next.
- **Programming blocks.** Set up lineups such as "Saturday Morning Cartoons" on chosen days and times. They can also run only during a date range each year, such as "Christmas Specials, Dec 1–25". A block plays a mix of shows, or a lineup you program slot by slot (DuckTales, then two Animaniacs, then Rugrats), with each show playing its next episode every airing. Each airing picks up where the last one left off.
- **Commercial breaks (experimental, off by default).** Make TV feel like TV again, with ads between and during shows:
  - **Your own ads.** Pick the Jellyfin folders that hold your commercials and bumpers. Their videos leave your regular channels and fill the breaks instead.
  - **Ad compilations split automatically.** Long compilations (an hour of '80s ads in one file, say) are cut into individual ads at chapters, or, using ffmpeg, where the picture goes black and silent.
  - **Breaks where they belong.** Ads play before, during and after shows and movies. Mid-show breaks go at act breaks when the show's chapters mark them, and otherwise at a scene change near evenly spaced points.
  - **Automatic or Custom.** **Automatic** lays breaks out broadcast-style, so shows start on the hour and half hour. **Custom** lets you set how long each break is, how often shows break, and which ads each break uses. Use one setting for every channel, or give a channel its own.
  - **Same ads for everyone.** Like real TV, tuning away and back shows the same ads at the same spot. Ads never show up in your Jellyfin watch history.

  Being experimental, this feature may change between versions, and splitting a long compilation for the first time can take several minutes. The rest of the app works the same with breaks off.
- **Profiles.** Everyone gets their own sign-in, channels and blocks. Kid profiles only see content rated for their age. Grown-up profiles and settings can be locked with a PIN.
- **Phone remote.** Turn it on in the menu, scan the QR code, and your phone's browser becomes the remote. There's nothing to install.
- **Always direct play.** Nightingale TV plays your original files and never asks Jellyfin to transcode, unless you turn on *Transcode only if needed*.
- **Bitrate cap.** With *Transcode only if needed* on, pick a maximum bitrate from 40 Mbps down to 4 Mbps for Wi-Fi or a remote connection. Your server converts a show only when it's over the cap you picked, and nothing lowers it while you watch. *Original* (the default) never converts because of bitrate.
- **Live TV export (HDHomeRun, M3U and XMLTV).** Watch your channels in Jellyfin Live TV, Plex or any IPTV app on your home network. Turn it on for each profile you want to share:
  - **HDHomeRun tuner.** Each exported profile shows up as its own network TV tuner. Add it in Jellyfin or Plex by its address, or let Plex find it on the network.
  - **M3U playlist.** A playlist of the profile's channels, with numbers, names and logos, for Jellyfin's M3U tuner and IPTV apps such as VLC, Kodi and TiviMate.
  - **XMLTV guide.** Three days of listings from the same schedule as the on-screen guide, with episode titles, season and episode numbers, descriptions, posters and programming blocks.
  - **Plays like this TV.** Each channel is one continuous stream that joins mid-show, with the same breaks and the same ads at the same moments.

  See [Live TV export](#live-tv-export) for setup.

| Who's watching? | Phone remote | Programming block editor |
| --- | --- | --- |
| ![Profile picker](docs/screenshots/profiles.png) | ![Phone remote](docs/screenshots/phone-remote.png) | ![Programming block editor](docs/screenshots/programming-block.png) |

## Install

Ready-made installers aren't published yet. For now, build one yourself: set up the tools in [Building from source](#building-from-source), then run this from the project folder:

```bash
tool/build_deb.sh
sudo apt install ./dist/nightingale-tv_*_amd64.deb
```

`apt` also installs the libraries Nightingale TV needs. Afterward, open **Nightingale TV** from your app menu, or run `nightingale-tv`.

To uninstall it: `sudo apt remove nightingale-tv`. Your settings in `~/.local/share/com.coffeehauslabs.nightingale_tv` are kept.

### On Android

There is one app for Android TVs, phones and tablets (Android 7.0 or newer). Build the APKs as described in [Building for Android](#building-for-android), then install the one for the device:

| APK | For |
| --- | --- |
| `nightingale-tv_<version>_arm64-v8a.apk` | Most TVs, TV boxes and phones from the last several years (Google TV, NVIDIA Shield, Fire TV Stick 4K and newer, Pixel, Galaxy…) |
| `nightingale-tv_<version>_armeabi-v7a.apk` | Older or cheaper TV sticks and boxes (Fire TV Stick Lite and older, many no-name boxes) |
| `nightingale-tv_<version>_universal.apk` | Any of them, if you're not sure. It's several times larger. |
| `nightingale-tv_<version>_x86_64.apk` | Android Studio emulators on a PC |

Ways to install it:

- **From a PC, over the network or USB:** turn on *Developer options* and *USB debugging* (or *Network debugging*) on the device, then `adb install nightingale-tv_<version>_arm64-v8a.apk`.
- **On an Android TV or Google TV:** put the APK on a web server or cloud drive, open it with an app such as *Downloader*, and allow that app to *Install unknown apps* when asked.
- **On a Fire TV:** Settings → My Fire TV → Developer options → *Install unknown apps* → turn on *Downloader*, then download the APK in Downloader and install it.
- **On a phone or tablet:** open the APK from the browser's downloads or a file manager, and allow *Install unknown apps* when asked.

It shows up in the TV's apps row and the phone's app drawer as **Nightingale TV**. Updates install over it, keeping your profiles, as long as they're built with the same release key.

On Android the app always fills the screen, runs sideways on phones, and keeps the screen from turning off while it's in front. Going to the home screen stops playback, and coming back tunes in to the same channel live.

**Not on Android:**

- **Live TV export.** It needs ffmpeg and a PC that stays on. It's not in the menu on Android.
- **Splitting ad compilations by picture and sound.** Without ffmpeg, compilations are split at their chapters (or Jellyfin's media segments) only. A long compilation without chapters isn't split, and the commercials screen says so.

### What you need

- A 64-bit PC running Ubuntu 24.04 or newer, or a similar Debian-based Linux.
- A [Jellyfin](https://jellyfin.org) server (10.11 or newer) with your shows and movies.
- ffmpeg, which `apt` installs with the app. It splits long commercial compilations into individual ads.
- For the phone remote, a phone on the same Wi-Fi as the PC. If the PC's firewall blocks it, allow the remote's port once: `sudo ufw allow 8642/tcp`.

## First start

1. Enter your Jellyfin server's address.
2. Sign in with your username and password, or with **Quick Connect**, approving the TV from the Jellyfin app on your phone.
3. The app scans your library and builds your channels. That's it. It starts on channel 2.

## Controls

| Key | Watching TV | In the guide |
| --- | --- | --- |
| ▲ ▼ / Page Up/Down | Change channel | Move between channels (▲ from the top row reaches **Menu**) |
| ◀ ▶ | Show the banner | Move through time |
| OK / Enter | Open the guide | Watch that channel |
| Esc / Back | Open the guide | Back to TV |
| 0–9 | Go to a channel number | |
| Backspace / L | Last channel | |
| C | Captions on/off | |
| M / right-click | Menu | Menu |
| F11 | Full screen on/off | |

**With an Android TV remote:** the D-pad, OK, Channel Up/Down, Info, Captions, Menu and number keys work as their keyboard keys do above. The remote's **Guide** button opens and closes the guide, and **Last** (or Recall) flips back to the previous channel. **Back** works as Esc does on every screen, except on the TV picture itself: there it shows "Press Back again to exit", and a second Back within 3 seconds closes the app.

**On a phone or tablet:** tap where you'd click and long-press where you'd right-click (the TV picture or the guide opens the menu). Drag to scroll the guide and lists. The back gesture works as the Back button does.

**With an air mouse:** move the pointer while watching, and **Guide** and **Menu** buttons appear in the top-left corner. In the guide, click a channel to watch it, or click **Menu** at the top.

## Live TV export

Live TV export lets the Plex and Jellyfin apps on your other TVs, phones and computers play your channels, guide and all, without installing anything new on them. The schedule, programming blocks and commercial breaks are the same as on this TV, with the same ads at the same moments.

Nightingale TV has to stay open for the exported channels to play. Closing it takes them off the air.

**Turn it on:** Menu → **Live TV export**. Turn on **Live TV export**, then **export this lineup** for each profile you want to share. Each profile gets its own address, for example `http://192.168.1.20:5004`, and the screen shows its links and a QR code.

**Plex** (Live TV needs Plex Pass): Settings → **Live TV & DVR** → **Set up Plex DVR**. Plex usually finds "Nightingale TV (*profile*)" on its own. If it doesn't, choose *Don't see your HDHomeRun device? Enter its network address manually* and type the profile's address. When Plex asks for a guide, choose the XMLTV option and paste the profile's **XMLTV** link.

**Jellyfin:** Dashboard → **Live TV** → add a **Tuner device** of type *HDHomeRun* with the profile's address (or type *M3U Tuner* with its **M3U** link). Then add a **TV Guide Data Provider** of type *XMLTV* with the **XMLTV** link.

**IPTV apps** (VLC, Kodi, TiviMate…): open the profile's **M3U** link.

Good to know:

- Exported channels are converted on this PC, so any player can show them. Nightingale TV uses your graphics card for this when it can. Jellyfin still does no converting. How many channels can be watched elsewhere at once is set under **Streams at once**.
- Anyone on your home network can watch an exported lineup, just as with a real tuner. Kid profiles' lineups only ever contain what that kid can watch.
- If the PC's firewall is on, allow the profile's port, and port 1900 so Plex can find it: `sudo ufw allow 5004/tcp` and `sudo ufw allow 1900/udp`.
- Plex and Jellyfin remember the address, so give this PC a fixed address in your router (a "DHCP reservation").
- Plex and Jellyfin refresh the guide on their own schedule. After changing channels or blocks, refresh the guide there to see it sooner. What plays is always up to date.

## Building from source

On Ubuntu:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev ffmpeg
sudo snap install flutter --classic

flutter pub get
flutter run -d linux        # NIGHTINGALE_TV_WINDOWED=1 runs it in a window
flutter test                # unit tests
tool/install.sh             # build and install for the current user
tool/build_deb.sh           # build dist/nightingale-tv_<version>_amd64.deb
```

### Building for Android

You need the Android SDK (Android Studio installs it) as well as Flutter. To try it on a connected device or a running emulator, `flutter run` is enough. For APKs you can install anywhere, build them signed with a release key.

Create the key once, and keep it and its passwords somewhere safe outside this repository. Every update must be signed with the same key, or Android won't install it over the old version:

```bash
keytool -genkey -v -keystore ~/nightingale-tv-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias nightingale-tv
```

Then create `android/key.properties` (it's git-ignored):

```properties
storeFile=/home/<you>/nightingale-tv-release.jks
keyAlias=nightingale-tv
storePassword=<keystore password>
keyPassword=<key password>
```

You can leave the two password lines out and pass them when building instead: `NIGHTINGALE_TV_STORE_PASSWORD=… NIGHTINGALE_TV_KEY_PASSWORD=… tool/build_apk.sh`.

```bash
tool/build_apk.sh           # build the four APKs in dist/ and print their sizes
```

Release builds stop with these instructions if there's no key. They never fall back to a debug key, because Android won't install a properly signed update over a debug-signed app without uninstalling it, and that loses your profiles.

## License

Nightingale TV is **free and open source software**, licensed under the [GNU General Public License, version 3](LICENSE) or (at your option) any later version.

You're free to use, study, copy, modify and redistribute it, and even sell it. If you distribute it, modified or not, you must pass on the same freedoms: share the source code under the GPL and keep the copyright and license notices. Nightingale TV comes with no warranty; see the license for details.

Copyright © 2026 tcaplette.

### Third-party software

Nightingale TV is built with software that keeps its own licenses:

- The [Barlow](https://github.com/jpt/barlow) fonts are under the SIL Open Font License 1.1 ([`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)).
- [Flutter](https://flutter.dev), [media_kit](https://github.com/media-kit/media-kit), [qr_flutter](https://pub.dev/packages/qr_flutter) and the other packages listed in [`pubspec.yaml`](pubspec.yaml) are under their own open-source licenses.
- On a PC, video playback uses [mpv](https://mpv.io) (libmpv), installed from your Linux distribution's packages. On Android it uses [AndroidX Media3](https://developer.android.com/media/media3) (ExoPlayer) with [OkHttp](https://square.github.io/okhttp/), both under the Apache License 2.0.

Nightingale TV is an independent project. It isn't affiliated with or endorsed by Jellyfin or NostalgiaTV. It doesn't include any TV network logos or other trademarks.
# Nightingale-TV
