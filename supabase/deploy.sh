#!/usr/bin/env bash
# Deploys the sharing backend to any Supabase project (see SELF_HOSTING.md):
#   migrations  the schema and row-level security (like `supabase db push --db-url`)
#   secrets     Edge Function secrets from supabase/functions/.env
#   auth        Auth email settings: auth-config.base.json with the private
#               auth-config.json merged over it (SMTP sender, site_url)
#   functions   every Edge Function, or the ones named (like `supabase functions deploy`)
#   all         migrations, secrets, auth, functions, in that order (the default)
# Every project-specific value comes from the credentials file: supabase-credentials.txt
# at the repository root, or the file named with --creds <file>. Everything a step needs
# is checked before any request is made, so a missing or placeholder value changes nothing.
# verify_jwt is off everywhere: the user-facing functions check the caller with Auth themselves.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
usage="usage: $0 [--creds <file>] [migrations|secrets|auth|functions [name…]|all]"

creds="$here/../supabase-credentials.txt"
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --creds) [ $# -ge 2 ] || { echo "$usage" >&2; exit 2; }; creds="$2"; shift 2 ;;
    --creds=*) creds="${1#--creds=}"; shift ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]+"${args[@]}"}"
what="${1:-all}"; shift || true
case "$what" in
  migrations|secrets|auth|functions|all) ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

die() { echo "$*" >&2; exit 1; }

# KEY=VALUE lines; # comments and blank lines skipped. Read as data, never sourced.
[ -f "$creds" ] || die "credentials file not found: $creds (copy supabase-credentials.example.txt)"
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  [[ "$line" == *=* ]] || continue
  k="${line%%=*}"; v="${line#*=}"
  k="${k//[[:space:]]/}"
  [[ "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
  export "$k=$v"
done < "$creds"
for k in SUPABASE_PROJECT_REF SUPABASE_ACCESS_TOKEN SUPABASE_DB_PASSWORD SUPABASE_DB_HOST; do
  v="${!k:-}"
  [ -n "$v" ] || die "$k is missing"
  [[ "$v" != \<* ]] || die "$k is not filled in"
done
# The ref alone, or any dashboard / project address that contains it.
REF=$(echo "$SUPABASE_PROJECT_REF" | grep -oE '\b[a-z]{20}\b' | head -1 || true)
[ -n "$REF" ] || die "SUPABASE_PROJECT_REF has no 20-letter project ref in it"
API="https://api.supabase.com/v1/projects/$REF"
AUTH=(-H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN")
DB="host=$SUPABASE_DB_HOST port=5432 user=postgres.$REF dbname=postgres sslmode=require"

secrets_json="$here/.secrets.json"
auth_merged="$here/.auth-merged.json"
trap 'rm -f "$secrets_json" "$auth_merged"' EXIT

# ---- Checks (no network) ------------------------------------------------------------

check_secrets() {
  python3 - "$here/functions/.env" "$secrets_json" <<'PY'
import json, os, sys
src, out_path = sys.argv[1], sys.argv[2]
if not os.path.isfile(src):
    sys.exit(f"{src} not found (copy supabase/functions/.env.example)")
out = []
for line in open(src):
    line = line.strip()
    if line and not line.startswith('#') and '=' in line:
        k, v = line.split('=', 1)
        k, v = k.strip(), v.strip()
        if not v or v.startswith('<'):
            sys.exit(f"{k} is not filled in")
        out.append({"name": k, "value": v})
names = {s["name"] for s in out}
for k in ("PREVIEW_SALT", "INVITE_ORIGIN"):
    if k not in names:
        sys.exit(f"{k} is missing")
with open(out_path, "w") as f:
    json.dump(out, f)
PY
}

check_auth() {
  python3 - "$here/auth-config.base.json" "$here/auth-config.json" "$auth_merged" <<'PY'
import json, os, sys
base_path, private_path, out_path = sys.argv[1:4]
PRIVATE = ["site_url", "smtp_host", "smtp_port", "smtp_user", "smtp_pass",
           "smtp_admin_email", "smtp_sender_name"]
base = json.load(open(base_path))
leaked = sorted(k for k in base if k == "site_url" or k.startswith("smtp_") and k != "smtp_max_frequency")
if leaked:
    sys.exit(f"auth-config.base.json must not hold {', '.join(leaked)}: those go in auth-config.json")
if not os.path.isfile(private_path):
    sys.exit(f"{private_path} not found (copy supabase/auth-config.example.json)")
private = json.load(open(private_path))
for k in PRIVATE:
    v = private.get(k)
    if v is None or str(v).strip() == "":
        sys.exit(f"{k} is missing")
    if str(v).strip().startswith("<"):
        sys.exit(f"{k} is not filled in")
merged = {**base, **private}
if not str(merged.get("smtp_pass", "")).strip():
    sys.exit("smtp_pass is missing")
with open(out_path, "w") as f:
    json.dump(merged, f)
PY
}

# ---- Steps --------------------------------------------------------------------------

migrations() {
  PGPASSWORD="$SUPABASE_DB_PASSWORD" psql "$DB" -qX -v ON_ERROR_STOP=1 -c \
    "create schema if not exists supabase_migrations;
     create table if not exists supabase_migrations.schema_migrations
       (version text primary key, statements text[], name text);"
  for f in "$here"/migrations/*.sql; do
    b=$(basename "$f" .sql); v=${b%%_*}; n=${b#*_}
    done_=$(PGPASSWORD="$SUPABASE_DB_PASSWORD" psql "$DB" -qXtA -c \
      "select 1 from supabase_migrations.schema_migrations where version='$v'")
    if [ -n "$done_" ]; then echo "migration $b: already applied"; continue; fi
    echo "migration $b: applying"
    { echo "begin;"; cat "$f";
      echo "insert into supabase_migrations.schema_migrations (version, name) values ('$v', '$n');";
      echo "commit;"; } | PGPASSWORD="$SUPABASE_DB_PASSWORD" psql "$DB" -qX -v ON_ERROR_STOP=1
  done
}

secrets() {
  curl -fsS -X POST "${AUTH[@]}" -H 'Content-Type: application/json' \
    --data @"$secrets_json" "$API/secrets" >/dev/null
  rm -f "$secrets_json"
  echo "secrets: set"
}

auth() {
  curl -fsS -X PATCH "${AUTH[@]}" -H 'Content-Type: application/json' \
    --data @"$auth_merged" "$API/config/auth" >/dev/null
  rm -f "$auth_merged"
  echo "auth: email settings set"
}

functions() {
  local names=("$@")
  [ ${#names[@]} -gt 0 ] || names=($(cd "$here/functions" && ls -d */ | tr -d /))
  for n in "${names[@]}"; do
    [ -f "$here/functions/$n/index.ts" ] || die "no function named $n"
  done
  for n in "${names[@]}"; do
    curl -fsS -X POST "${AUTH[@]}" "$API/functions/deploy?slug=$n" \
      -F "metadata={\"entrypoint_path\":\"index.ts\",\"name\":\"$n\",\"verify_jwt\":false};type=application/json" \
      -F "file=@$here/functions/$n/index.ts;filename=index.ts" >/dev/null
    echo "function $n: deployed"
  done
}

case "$what" in
  migrations) migrations ;;
  secrets) check_secrets; secrets ;;
  auth) check_auth; auth ;;
  functions) functions "$@" ;;
  all) check_secrets; check_auth; migrations; secrets; auth; functions ;;
esac
