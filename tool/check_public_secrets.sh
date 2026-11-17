#!/usr/bin/env bash
# Fails if any value from the private sharing files appears in a file that would be
# published (self-hosted-sharing D7). Run it before pushing a fork or a release.
#
#   tool/check_public_secrets.sh [--repo <dir>] [--private <dir>] [--list-files]
#
# --repo <dir>     the tree to check (default: this repository)
# --private <dir>  where the private files are (default: the --repo tree):
#                    sharing.env, supabase-credentials.txt,
#                    supabase/auth-config.json, supabase/functions/.env
# --list-files     only print the files that would be published, one per line
#
# "Would be published" means every file not ignored by the .gitignore files in the tree
# (read by this script; it makes no VCS calls). Values shorter than 8 characters are
# skipped, and so are the keys whose values every user sees anyway (PUBLIC_KEYS below:
# the invite host, the email sender's name and SMTP server). Every credential and
# project identifier is checked. Values are never printed: a hit names the file and
# the private key only.
# It also fails if a private file is missing from the top-level .gitignore.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
repo="$here"; private=""; list=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$(cd "$2" && pwd)"; shift 2 ;;
    --private) private="$(cd "$2" && pwd)"; shift 2 ;;
    --list-files) list=1; shift ;;
    -h|--help) sed -n 2,17p "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$private" ] || private="$repo"

exec python3 -I - "$repo" "$private" "$list" <<'PY'
import json, os, re, sys

repo, private, list_only = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
PRIVATE = ["sharing.env", "supabase-credentials.txt",
           "supabase/auth-config.json", "supabase/functions/.env"]

# Values that are public by design: shown in every invite link or sign-in email, or the
# SMTP provider's well-known server. They also appear in the README and the app.
PUBLIC_KEYS = {"NTV_SHARE_HOST", "INVITE_ORIGIN", "site_url", "smtp_host", "smtp_port",
               "smtp_user", "smtp_sender_name"}
# auth-config.json's own keys; anything else in it belongs in the committed base file.
AUTH_PRIVATE = {"site_url", "smtp_host", "smtp_port", "smtp_user", "smtp_pass",
                "smtp_admin_email", "smtp_sender_name"}

# ---- .gitignore matching (the subset git documents: anchors, dir-only, *, **, ?, !) ----
def compile_pattern(pat):
    neg = pat.startswith("!")
    if neg:
        pat = pat[1:]
    if pat.startswith("\\"):
        pat = pat[1:]
    dir_only = pat.endswith("/")
    pat = pat.rstrip("/")
    anchored = "/" in pat
    pat = pat.lstrip("/")
    i, out = 0, ""
    while i < len(pat):
        c = pat[i]
        if pat.startswith("**/", i):
            out += "(?:.*/)?"; i += 3; continue
        if pat.startswith("/**", i) and i + 3 == len(pat):
            out += "/.*"; i += 3; continue
        if pat.startswith("**", i):
            out += ".*"; i += 2; continue
        if c == "*":
            out += "[^/]*"
        elif c == "?":
            out += "[^/]"
        elif c == "[":
            j = pat.find("]", i)
            if j < 0:
                out += re.escape(c)
            else:
                cls = pat[i + 1:j]
                if cls.startswith("!"):
                    cls = "^" + cls[1:]
                out += "[" + cls + "]"
                i = j
        else:
            out += re.escape(c)
        i += 1
    rx = re.compile(("^" if anchored else "^(?:.*/)?") + out + "$")
    return rx, neg, dir_only

def read_rules(d):
    p = os.path.join(d, ".gitignore")
    rules = []
    if os.path.isfile(p):
        for line in open(p, encoding="utf-8", errors="replace"):
            line = line.rstrip("\n").rstrip()
            if not line or line.startswith("#"):
                continue
            rules.append(compile_pattern(line))
    return rules

def ignored(stack, rel, is_dir):
    result = False
    for base, rules in stack:
        sub = rel[len(base) + 1:] if base else rel
        for rx, neg, dir_only in rules:
            if dir_only and not is_dir:
                continue
            if rx.match(sub):
                result = not neg
    return result

def published_files(root):
    out = []
    def walk(d, rel, stack):
        stack = stack + [(rel, read_rules(d))]
        for name in sorted(os.listdir(d)):
            if name == ".git":
                continue
            p = os.path.join(d, name)
            r = f"{rel}/{name}" if rel else name
            is_dir = os.path.isdir(p) and not os.path.islink(p)
            if ignored(stack, r, is_dir):
                continue
            if is_dir:
                walk(p, r, stack)
            elif os.path.isfile(p):
                out.append(r)
    walk(root, "", [])
    return out

files = published_files(repo)
if list_only:
    for f in files:
        print(f)
    sys.exit(0)

problems = 0

# ---- Every private file is ignored by name, and none would be published ----
top = [l.strip() for l in open(os.path.join(repo, ".gitignore"), encoding="utf-8")]
for f in PRIVATE:
    if "/" + f not in top and f not in top:
        print(f"FAIL .gitignore does not list /{f}")
        problems += 1
    if f in files:
        print(f"FAIL {f} would be published")
        problems += 1

# ---- Collect the private values (never printed) ----
values = {}  # value -> "file:key"
found = 0
def add(src, key, v):
    if key in PUBLIC_KEYS:
        return
    v = str(v).strip()
    if len(v) >= 8 and not v.startswith("<"):
        values.setdefault(v, f"{src}:{key}")

for f in PRIVATE:
    p = os.path.join(private, f)
    if not os.path.isfile(p):
        continue
    found += 1
    if f.endswith(".json"):
        for k, v in json.load(open(p)).items():
            if k in AUTH_PRIVATE and isinstance(v, (str, int)) and not isinstance(v, bool):
                add(f, k, v)
    else:
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                add(f, k.strip(), v)

if found == 0:
    print(f"FAIL no private files found under {private}: nothing to check against")
    sys.exit(1)

# ---- Search every published file ----
hits = 0
for rel in files:
    try:
        data = open(os.path.join(repo, rel), "rb").read()
    except OSError:
        continue
    for v, where in values.items():
        if v.encode() in data:
            print(f"FAIL {rel} contains the value of {where}")
            hits += 1

problems += hits
if problems:
    print(f"{problems} problem(s); values not shown")
    sys.exit(1)
print(f"ok: {len(values)} private values, none in {len(files)} published files; private files ignored")
PY
