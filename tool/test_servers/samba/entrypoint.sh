#!/bin/sh
# One Samba server per kind of host the app has to work with, each with its
# own rules, plus NetBIOS names. SMB_USER and SMB_PASSWORD sign in.
#
#   1445  SMB 2 and 3: media (password, writable), archive (the same sign-in
#         on the same host, writable), guest (no sign-in, writable), readonly
#         (password), private (nobody's, so "No access")
#   1446  Windows' rules, signing required and no guests: signed (password)
#   1447  SMB1 only: old (password), oldguest (no sign-in)
#
# "wsdd" instead answers WS-Discovery as a Windows computer would.
set -eu

if [ "${1:-}" = wsdd ]; then
  exec wsdd --hostname NTV-WINDOWS --workgroup WORKGROUP --shortlog
fi

: "${SMB_USER:?}" "${SMB_PASSWORD:?}"
uid="${HOST_UID:-1000}" gid="${HOST_GID:-1000}"
grep -q "^media:" /etc/group || addgroup -g "$gid" media
for user in "$SMB_USER" other; do
  id "$user" >/dev/null 2>&1 || adduser -D -H -s /sbin/nologin "$user"
done
id media >/dev/null 2>&1 || adduser -D -H -s /sbin/nologin -u "$uid" -G media media

global() { # name, port
  cat <<CONF
[global]
  netbios name = $1
  server string = Nightingale test share
  workgroup = WORKGROUP
  smb ports = $2
  server role = standalone server
  passdb backend = tdbsam:/var/lib/samba/passdb.tdb
  private dir = /var/lib/samba/private
  lock directory = /run/samba-$2
  state directory = /run/samba-$2
  cache directory = /run/samba-$2
  pid directory = /run/samba-$2
  ncalrpc dir = /run/samba-$2/ncalrpc
  log file = /dev/stdout
  load printers = no
  disable spoolss = yes
  force user = media
  force group = media
  create mask = 0644
  directory mask = 0755
CONF
}

share() { # name, path, options...
  printf '[%s]\n  path = %s\n' "$1" "$2"
  shift 2
  for option in "$@"; do printf '  %s\n' "$option"; done
}

mkdir -p /run/samba-1445 /run/samba-1446 /run/samba-1447 /var/lib/samba/private
user="valid users = $SMB_USER"
{
  global NTVSAMBA 1445
  echo "  server min protocol = SMB2_02"
  echo "  map to guest = Bad User"
  share media /srv/media "$user" "read only = no"
  share archive /srv/formats "$user" "read only = no"
  share guest /srv/formats "guest ok = yes" "read only = no"
  share readonly /srv/media "$user" "read only = yes"
  share private /srv/media "valid users = other" "read only = yes"
} > /etc/samba/smb-1445.conf
{
  global NTVSIGNED 1446
  echo "  server min protocol = SMB2_10"
  echo "  server signing = mandatory"
  echo "  map to guest = Never"
  echo "  restrict anonymous = 2"
  share signed /srv/media "$user" "read only = no"
} > /etc/samba/smb-1446.conf
{
  global NTVOLD 1447
  echo "  server min protocol = CORE"
  echo "  server max protocol = NT1"
  echo "  ntlm auth = yes"
  echo "  map to guest = Bad User"
  share old /srv/media "$user" "read only = no"
  share oldguest /srv/formats "guest ok = yes" "read only = no"
} > /etc/samba/smb-1447.conf

for user in "$SMB_USER" other; do
  printf '%s\n%s\n' "$SMB_PASSWORD" "$SMB_PASSWORD" | smbpasswd -c /etc/samba/smb-1445.conf -s -a "$user" >/dev/null
done

nmbd -D -s /etc/samba/smb-1445.conf || true
for port in 1445 1446 1447; do
  smbd -F --no-process-group -s "/etc/samba/smb-$port.conf" &
done
wait
