# Running your own sharing backend

[Sharing](README.md#sharing) (friends, shared channels, what friends are watching, watching together) needs a backend. The official builds use the official one, whose keys are not in this repository. If you build Nightingale TV from source, you can run the same backend on your own [Supabase](https://supabase.com) project, send sign-in codes through your own email service, and serve invite links from your own website. This guide walks through it.

**A self-hosted backend is a separate network.** People on your builds can add each other as friends and share channels, but they can't add friends who use the official builds, and the reverse. Each build talks only to the backend in its own `sharing.env`.

What you need:

- a Supabase account (the free plan is enough);
- an email service that can send over SMTP from a domain you own ([Resend](https://resend.com) is used below; any SMTP service works);
- a website for invite links: [GitHub Pages](https://pages.github.com) or any static host, on its own host name;
- this repository, with `bash`, `curl`, `python3` and `psql` (PostgreSQL client) on the computer you deploy from.

Every private value goes into a git-ignored file. Each one has a committed `*.example` next to it: copy the example, then fill in the copy. Deploy from the same checkout you build from, so the backend's schema matches your app.

## 1. Make a Supabase project

On [supabase.com/dashboard](https://supabase.com/dashboard), choose **New project**. Pick a name, a region near your users and a strong database password, and keep that password: step 2 needs it.

Nothing else needs turning on. Email sign-in, Realtime and Edge Functions are on by default, and the deploy step (step 5) sets everything else.

## 2. Fill in the credentials file

```sh
cp supabase-credentials.example.txt supabase-credentials.txt
```

Fill in every value. The comments in the file say where each one is in the dashboard:

| Key | What it is |
| --- | --- |
| `SUPABASE_PROJECT_REF` | The 20-letter id in your dashboard address, `supabase.com/dashboard/project/<ref>` |
| `SUPABASE_ACCESS_TOKEN` | A personal access token, from **Account → Access Tokens** |
| `SUPABASE_DB_PASSWORD` | The database password from step 1 |
| `SUPABASE_DB_HOST` | The session pooler's host, from **Connect → Session pooler**, such as `aws-0-eu-west-2.pooler.supabase.com` |
| `SUPABASE_SECRET_KEY` | **Project Settings → API Keys → Secret key**. Only `tool/share_peer` (the test tool) uses it |
| `NTV_TEST_EMAIL` | Optional: an address of yours that receives mail, for `tool/share_peer`'s test accounts |

`supabase/deploy.sh` reads `supabase-credentials.txt` from the repository root. To keep the file somewhere else, pass `--creds <file>` to every deploy command.

## 3. Choose an email service

Supabase sends each sign-in code by email. Its built-in sender is only for testing (it sends a few emails an hour, and only to your own team), so use your own SMTP service.

```sh
cp supabase/auth-config.example.json supabase/auth-config.json
```

Fill in every value in `supabase/auth-config.json`:

| Key | Resend | Any other SMTP service |
| --- | --- | --- |
| `smtp_host` | `smtp.resend.com` | your provider's SMTP server |
| `smtp_port` | `465` | `465` (TLS) or `587` (STARTTLS) |
| `smtp_user` | `resend` | your SMTP user name |
| `smtp_pass` | your Resend API key (`re_…`); a key with **Sending access** is enough | your SMTP password |
| `smtp_admin_email` | the sender address, such as `noreply@example.org` | the same |
| `smtp_sender_name` | the sender's name, such as `Nightingale TV` | the same |
| `site_url` | your invite website's address from step 6, such as `https://invites.example.org` | the same |

**Verify the sender's domain** with your email service before deploying. With Resend, add your domain under **Domains** and create the DNS records it shows you (SPF and DKIM). Until the domain is verified, codes aren't delivered.

The code email's subject, text and layout, the 6-digit code length, the 10-minute expiry and the rate limits are in the committed `supabase/auth-config.base.json`, so every build's email looks the same. The deploy step merges your file over it. It refuses to run if a value in your file is missing or still a `<…>` placeholder.

## 4. Fill in the function secrets

```sh
cp supabase/functions/.env.example supabase/functions/.env
```

- `PREVIEW_SALT`: a random string of 32 characters or more, for example from `openssl rand -hex 24`. The invite preview uses it to count requests per address without storing the address.
- `INVITE_ORIGIN`: your invite website's origin from step 6, with no trailing slash, such as `https://invites.example.org` or `https://<user>.github.io`. Browsers may read invite previews only from this origin.

## 5. Deploy

```sh
supabase/deploy.sh all
```

This runs four steps in order. Each one can also be run on its own:

- `migrations`: the tables, the data rules (row-level security) and the database functions;
- `secrets`: the function secrets from step 4;
- `auth`: the email settings from step 3;
- `functions`: every Edge Function (`functions <name>…` deploys only those).

The script checks everything it needs before it makes a request, and stops with the name of anything missing, such as `SUPABASE_DB_HOST is missing` or `smtp_pass is not filled in`. Migrations that are already applied are skipped, so you can run `deploy.sh all` again after every update of your checkout.

## 6. Publish the invite page

An invite link is `https://<your host>/ntv/i/<CODE>`. Opened on a phone with your build installed, it opens the app. Anywhere else, the page shows who sent the invite and the code to type in the app. The page is the `invite_page/` folder: plain files, with no build step.

1. Copy the folder to where you'll publish it, such as a clone of your `<user>.github.io` repository, and make the changes below in that copy. Leave `invite_page/` in this repository as it is: your project's address must not go into it (step 9 checks for it).

   ```sh
   cp -r invite_page/. <your site folder>/
   ```

2. In the copy, fill in `config.js`:
   - `INVITE_API`: `https://<project ref>.supabase.co/functions/v1/invite-preview`;
   - `GET_APP_URL`: where people get your build, such as your fork's Releases page.
3. Let your app open invite links. In the copy, rename `.well-known/assetlinks.json.example` to `.well-known/assetlinks.json` and replace both `<SHA-256 of your signing cert>` placeholders with your release key's SHA-256 fingerprint:

   ```sh
   keytool -list -v -keystore <your release keystore> -alias <your key alias> | grep SHA256
   ```

   Your own builds' app id is `com.coffeehauslabs.nightingale_tv.selfbuilt` (see [Store version, official APKs and your own build](README.md#store-version-official-apks-and-your-own-build)). The example lists it, next to the store id.
4. Publish the whole copy at the **root** of a host, including the hidden `.nojekyll` file and `.well-known/` folder. App Links only work at the root of a host, so a GitHub Pages *project* site (`<user>.github.io/<repo>/`) won't do. Use one of these:
   - a GitHub Pages *user* site: a repository named `<user>.github.io` holding the files, served at `https://<user>.github.io`;
   - any repository's Pages site with a custom domain, such as `invites.example.org`;
   - any other static host. Unknown paths must be answered with `404.html`, which GitHub Pages, Netlify, Cloudflare Pages and most others do by default. The page reads the code from the address itself.

   `https://<your host>/.well-known/assetlinks.json` must load as JSON.

Until `assetlinks.json` is in place, invite links open the browser page, which still shows the code to type. The page's text is in English only.

Check that `site_url` (step 3) and `INVITE_ORIGIN` (step 4) are this host's address. If you changed either one, run `supabase/deploy.sh auth` and `supabase/deploy.sh secrets` again.

## 7. Fill in sharing.env

```sh
cp sharing.env.example sharing.env
```

- `NTV_SHARE_URL`: `https://<project ref>.supabase.co`;
- `NTV_SHARE_KEY`: the **publishable** key (`sb_publishable_…`) from **Project Settings → API Keys**. It's public by design, because the data rules protect the data. Never put the secret key here;
- `NTV_SHARE_HOST`: your invite host from step 6, with no `https://` and no path, such as `invites.example.org`.

If any of the three is empty, your builds have no Sharing.

## 8. Build a release

Only release builds have Sharing. `flutter run`, debug and profile builds never do.

- **Android:** set up your release key as described in [Building for Android](README.md#building-for-android), then run `tool/build_apk.sh`. The APKs in `dist/` have Sharing, and Android verifies your invite host for App Links when the app is installed.
- **Linux:** `tool/build_linux_release.sh` (or `tool/build_deb.sh` for a `.deb`); see [Building for Linux](README.md#building-for-linux).

Every build script reads `sharing.env` from the repository root when it's there.

**Releases built by GitHub Actions.** The Linux release workflow (`.github/workflows/linux-release.yml`) writes `sharing.env` from three repository secrets. In your fork, add `NTV_SHARE_URL`, `NTV_SHARE_KEY` and `NTV_SHARE_HOST` under **Settings → Secrets and variables → Actions**, with the same values as step 7. Without all three, the workflow's release has no Sharing and says so in a warning.

## 9. Check for secrets before publishing

Before you push your fork or publish a release, run:

```sh
tool/check_public_secrets.sh
```

It reads the four private files (`sharing.env`, `supabase-credentials.txt`, `supabase/auth-config.json`, `supabase/functions/.env`) and fails if any of their values appears in a file that would be published, meaning any file the `.gitignore` files don't exclude. It also fails if a private file isn't listed in `.gitignore`. It never prints a value, only the file and the name of the key it found. Values every user sees anyway, such as the invite host and the email sender's name, are not counted.

## Trying it out

With two release builds signed in to two accounts (two devices, or two profiles), choose **Sharing → Add friend** on one and enter its code on the other under **Add friend → Enter a code**. Then open the invite link on a phone.

`tool/share_peer` is a command-line second user for testing. It uses `sharing.env`, plus `SUPABASE_SECRET_KEY` and `NTV_TEST_EMAIL` from the credentials file. For example, `cd tool/share_peer && dart run bin/share_peer.dart invite <email>` prints a live friend code for that account and signs it up if it's new. The file's header lists every command.
