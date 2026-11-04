# Nightingale TV server

Runs [Nightingale TV](https://github.com/tcaplette/Nightingale-TV)'s channels on an always-on machine (a NAS, a home server) and serves them to Plex, Jellyfin, Emby or any IPTV app as a network tuner, with a guide, commercial breaks and channel logos, the same as on the TV.

## Install

1. Save [`docker-compose.yml`](docker-compose.yml) in a folder on the server, and set `PUID`, `PGID` (run `id` to see yours) and `TZ` in it.
2. Start it:
   ```
   docker compose up -d
   ```
3. Open the setup link from the log:
   ```
   docker compose logs | grep "to set up"
   ```
   Make the first admin account (a user name and a password), then either **Restore a backup** from the Nightingale TV app (Menu → Backup & restore → Back up now, then download it) or **Start fresh**, and sign in to your Jellyfin, Emby or Plex server.

Everything else is set up in the web admin at `http://<server>:8484`, from a computer or a phone: profiles, channels and their icons, programming blocks, channel groups, commercials, Live TV sources, export, backups and users. It works with no internet connection. The **Live TV export** page lists each lineup's tuner address, M3U and XMLTV URLs.

## Add the tuner

- **Plex:** Live TV & DVR → Set up Plex DVR → enter the tuner address from the web admin (`http://<server>:5004`).
- **Jellyfin / Emby:** Live TV → Tuner devices → add HD Homerun with that address, then add the XMLTV URL as the guide.
- **IPTV apps:** use the M3U and XMLTV URLs.

## Settings

| Variable | Default | |
|---|---|---|
| `PUID`, `PGID` | 1000 | user and group that own `/config` |
| `TZ` | UTC | time zone for the schedule and guide |
| `NTV_SETUP_PORT` | 8484 | web admin port |
| `NTV_LAN_HOST` | | address shown in the web admin's URLs (set it on a bridge network) |
| `NTV_RESET_PASSWORD` | | `1` for one start when an admin's password is forgotten (see below) |
| `NTV_WEB_DIR` | the image's `web/` | where the web admin is served from (only for trying one you built) |

Everything is kept in `/config`: the household in `/config/com.coffeehauslabs.nightingale_tv/`, with the user accounts in `nightingale.db` there, and caches in `/config/cache/`. Ports: 8484 (web admin), 5004 and up (one per exported profile).

## Users

Each person signs in to the web admin with their own account:

- **Admins** can do everything: users, profiles, export, backups and restore.
- **Users** see and edit only the profiles an admin assigns them (Users → Edit). A kid profile's settings ask a user for a grown-up profile's PIN, and a profile with a PIN asks for it once per session, as on the TV. Admins aren't asked.

Anyone can change their own password (Change password). Five wrong passwords in a minute from one address, or for one name, lock sign-in for a minute.

**Forgotten admin password:** add `NTV_RESET_PASSWORD: "1"` to the compose file and restart. Every session ends and a new setup link is logged; open it, pick the admin account and set its new password. Other accounts and their passwords stay as they are. Remove the variable again afterwards.

Backups made here hold the account names, roles and profiles, never passwords. Restored on a new server, each account that isn't there yet is added and shows **Needs a password** until an admin sets one; the admin who restored stays an admin. The TV app ignores the accounts.

## Upgrading from the first server image

The first image had one admin password. On the first start of a newer image it becomes the admin account **admin**, with the same password, and `admin.json` is renamed `admin.json.migrated`. Sign in as `admin` (browsers need to sign in once more).

To go back to the first image, rename `admin.json.migrated` back to `admin.json` in `/config/com.coffeehauslabs.nightingale_tv/` before starting it. It ignores `nightingale.db`; nothing else changed.

**Networking:** `docker-compose.yml` uses host networking. If that clashes with other ports on the machine, use [`docker-compose.bridge.yml`](docker-compose.bridge.yml) and set `NTV_LAN_HOST` to the server's address.

## Updating

```
docker compose pull && docker compose up -d
```

## Making a new image (maintainers)

1. Set `NTV_VERSION` in the [`Dockerfile`](Dockerfile) to the new version (for example `1.2.0`), so a local `docker build` gets the same one.
2. Publish the release with tag `v1.2.0` (pushing the tag, or creating the release on GitHub with a new tag). The "Linux release" workflow attaches `nightingale-tv-linux-x64-1.2.0.tar.gz` and its `.sha256` to it, then builds this folder's image from that file and publishes `ghcr.io/tcaplette/nightingale-tv-server:1.2.0` and `:latest`.

To build the image for a release that already exists: Actions → Linux release → Run workflow, with its tag (`v1.1.0`).

The first time, make the package public: GitHub → your profile → Packages → nightingale-tv-server → Package settings → Change visibility → Public.
