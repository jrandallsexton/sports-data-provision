#!/usr/bin/env bash
# One-time backup provisioning for the sportDeets data boxes.
# Run AS ROOT on the box:  sudo bash setup-data-backups.sh
#
# Detects which box it is on (postgres vs mongod) and installs:
#   - smbclient (userspace SMB3 for the Bender share -- kernel cifs mounts
#     corrupted large files and are deliberately NOT used; see the backup
#     script headers)
#   - /etc/sportsdata-backup/{config,smb-creds[,mongo.yaml]}
#   - /usr/local/sbin/sportsdata-backup.sh (the right one for the box)
#   - systemd service + timer (nightly, UTC; Persistent=true so a missed
#     run fires on next boot)
#
# Expects these files next to it (scp'd over beforehand):
#   sportsdata-pg-backup.sh / sportsdata-mongo-backup.sh
#   smb-creds   (username=... / password=... lines; NOT in source control)
#
# The Mongo box prompts for the mongod admin password interactively and
# writes it to /etc/sportsdata-backup/mongo.yaml (0600). Nothing secret is
# ever committed; this script only MOVES secrets into place.

set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)

SHARE_UNC=//192.168.0.4/sdprod-backups
RETAIN_REMOTE=7

if command -v psql >/dev/null 2>&1; then
  ROLE=pg
  BACKUP_ROOT=/var/lib/postgresql/backups   # big volume: 268G free
  ONCAL="*-*-* 09:00:00"                    # boxes run UTC; ~4am Central
elif command -v mongod >/dev/null 2>&1; then
  ROLE=mongo
  BACKUP_ROOT=/var/backups/sportsdata
  ONCAL="*-*-* 08:30:00"                    # offset so both boxes don't hit Bender at once
else
  echo "neither psql nor mongod found - wrong box?"; exit 1
fi
echo "detected role: $ROLE"

# ── Packages ────────────────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get -qq update
apt-get -qq install -y smbclient

# ── Config + secrets ────────────────────────────────────────────────────────
install -d -m 0700 /etc/sportsdata-backup
[ -f "$HERE/smb-creds" ] || { echo "missing $HERE/smb-creds"; exit 1; }
install -m 0600 "$HERE/smb-creds" /etc/sportsdata-backup/smb-creds

cat > /etc/sportsdata-backup/config <<EOF
SHARE_UNC=$SHARE_UNC
SMB_CREDS=/etc/sportsdata-backup/smb-creds
BACKUP_ROOT=$BACKUP_ROOT
RETAIN_REMOTE=$RETAIN_REMOTE
EOF
chmod 0600 /etc/sportsdata-backup/config

if [ "$ROLE" = mongo ] && [ ! -f /etc/sportsdata-backup/mongo.yaml ]; then
  read -r -s -p "mongod 'admin' user password: " MPW; echo
  printf 'password: "%s"\n' "$MPW" > /etc/sportsdata-backup/mongo.yaml
  chmod 0600 /etc/sportsdata-backup/mongo.yaml
  unset MPW
fi

# ── Backup script ───────────────────────────────────────────────────────────
install -m 0755 "$HERE/sportsdata-$ROLE-backup.sh" /usr/local/sbin/sportsdata-backup.sh
install -d -m 0700 "$BACKUP_ROOT"

# ── smoke-test SMB access + ensure the host dir exists ──────────────────────
smbclient "$SHARE_UNC" -A /etc/sportsdata-backup/smb-creds -c "mkdir $(hostname)" 2>/dev/null || true
smbclient "$SHARE_UNC" -A /etc/sportsdata-backup/smb-creds -D "$(hostname)" -c "ls" > /dev/null
echo "SMB access verified"

# ── systemd units ───────────────────────────────────────────────────────────
cat > /etc/systemd/system/sportsdata-backup.service <<EOF
[Unit]
Description=sportDeets nightly database backup to Bender
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/sportsdata-backup.sh
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF

cat > /etc/systemd/system/sportsdata-backup.timer <<EOF
[Unit]
Description=Nightly sportDeets database backup

[Timer]
OnCalendar=$ONCAL
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now sportsdata-backup.timer
systemctl list-timers sportsdata-backup.timer --no-pager | head -3

echo
echo "Setup complete. First backup: systemctl start sportsdata-backup.service"
echo "Watch it:                     journalctl -fu sportsdata-backup.service"
