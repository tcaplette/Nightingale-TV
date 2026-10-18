# Nightingale TV

Nightingale TV turns your Jellyfin library into always-on cable TV channels, with a program guide, for a Linux PC hooked up to a TV. Like real TV, every channel is always mid-broadcast. You tune in to whatever is on, flip channels, and check the guide to see what's coming up.

It's inspired by NostalgiaTV for Android. It's built for the couch, so everything works with a keyboard, a mouse, an air mouse, or your phone.

![The program guide, with a programming block on channel 2](docs/screenshots/guide.png)

## Features

- **Channels made for you.** The app builds a lineup from your library: an all-shows channel, genre channels (comedy, kids, sci-fi…), marathon channels for your biggest shows, and movie channels. You can rename, renumber, hide or favorite any channel, and give it a built-in icon, a station badge, a show logo or your own image.
- **Always on the air.** Channels run on the clock, so you join a show mid-episode, just like flipping to it on cable.
- **Program guide.** A scrolling cable-style grid with a live preview window.
- **Programming blocks.** Set up lineups such as "Saturday Morning Cartoons" on chosen days and times. They can also run only during a date range each year, such as "Christmas Specials, Dec 1–25". Each airing picks up where the last one left off.
- **Commercial breaks (optional).** Pick the Jellyfin folders that hold your commercials and bumpers; long ad compilations are split into individual ads automatically. Breaks come before, during and after shows and movies, at act breaks when they can be found. Choose **Automatic** for a broadcast-style layout on the half hour, or **Custom** to set each break yourself, for every channel or just one. Breaks are off by default.
- **Profiles.** Everyone gets their own sign-in, channels and blocks. Kid profiles only see content rated for their age. Grown-up profiles and settings can be locked with a PIN.
- **Phone remote.** Turn it on in the menu, scan the QR code, and your phone's browser becomes the remote. There's nothing to install.

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

**With an air mouse:** move the pointer while watching, and **Guide** and **Menu** buttons appear in the top-left corner. In the guide, click a channel to watch it, or click **Menu** at the top.

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

## License

Nightingale TV is **free and open source software**, licensed under the [GNU General Public License, version 3](LICENSE) or (at your option) any later version.

You're free to use, study, copy, modify and redistribute it, and even sell it. If you distribute it, modified or not, you must pass on the same freedoms: share the source code under the GPL and keep the copyright and license notices. Nightingale TV comes with no warranty; see the license for details.

Copyright © 2026 tcaplette.

### Third-party software

Nightingale TV is built with software that keeps its own licenses:

- The [Barlow](https://github.com/jpt/barlow) fonts are under the SIL Open Font License 1.1 ([`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)).
- [Flutter](https://flutter.dev), [media_kit](https://github.com/media-kit/media-kit), [qr_flutter](https://pub.dev/packages/qr_flutter) and the other packages listed in [`pubspec.yaml`](pubspec.yaml) are under their own open-source licenses.
- Video playback uses [mpv](https://mpv.io) (libmpv), installed from your Linux distribution's packages.

Nightingale TV is an independent project. It isn't affiliated with or endorsed by Jellyfin or NostalgiaTV. It doesn't include any TV network logos or other trademarks.
# Nightingale-TV
