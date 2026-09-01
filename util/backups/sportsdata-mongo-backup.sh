#!/usr/bin/env bash
# Nightly MongoDB backup — runs on sdprod-data-00 as root (systemd timer).
#
# This corpus is the ESPN document cache — the one dataset that CANNOT be
# re-sourced if ESPN ever locks down, which makes it the most
# backup-worthy data in the platform despite being "just a cache".
#
# Transport is smbclient (userspace SMB3) with a re-download hash verify;
# see the header of sportsdata-pg-backup.sh for why kernel cifs and curl
# were both rejected. One artifact per run: <UTC timestamp>.tar
# (+ .sha256) under sdprod-backups/<hostname>/ on Bender. The tar wraps
# mongodump's <db>/<collection>.bson.gz tree plus a MANIFEST.
#
# Restore: tar -xf <ts>.tar -C <dir>; mongorestore --gzip --dir <dir>
#
# Auth: password lives in /etc/sportsdata-backup/mongo.yaml (root 0600),
# passed via --config so it never appears on a command line / in ps. The
# admin user carries the `backup` role — readWriteAnyDatabase alone cannot
# read the `config` db and the first run failed exactly there.
#
# Disk ordering note: the staging tree is deleted after upload, BEFORE the
# verify re-download — this box has ~72G free and the peak would not fit
# otherwise. If the verify fails, the local tar still exists for retry.

set -euo pipefail

CONF=/etc/sportsdata-backup/config
# shellcheck source=/dev/null
source "$CONF" # SHARE_UNC, SMB_CREDS, BACKUP_ROOT, RETAIN_REMOTE

MONGO_CONF=/etc/sportsdata-backup/mongo.yaml
HOST=$(hostname)
TS=$(date -u +%Y-%m-%dT%H%M%SZ)
STAGE="$BACKUP_ROOT/stage-$TS"
TAR="$BACKUP_ROOT/$TS.tar"

smb() { smbclient "$SHARE_UNC" -A "$SMB_CREDS" -D "$HOST" -c "$1"; }

exec 9>/run/sportsdata-backup.lock
flock -n 9 || { echo "previous backup still running; skipping"; exit 0; }

echo "backup starting: $TS"
mkdir -p "$STAGE"

# Free the space held by the previous run's artifact up front — this box
# cannot hold two tars plus a staging tree at once. Bender still holds
# RETAIN_REMOTE verified nightlies, so the brief local gap is acceptable.
find "$BACKUP_ROOT" -maxdepth 1 \( -name '*.tar' -o -name '*.tar.sha256' \) -delete

# ── Dump ────────────────────────────────────────────────────────────────────
mongodump \
  --host 127.0.0.1 --port 27017 \
  --username admin --authenticationDatabase admin \
  --config "$MONGO_CONF" \
  --gzip --out "$STAGE"

# A silently-empty run must not rotate good backups out.
BSON_COUNT=$(find "$STAGE" -name '*.bson.gz' | wc -l)
[ "$BSON_COUNT" -gt 0 ] || { echo "FAIL: dump produced no collections"; exit 1; }
find "$STAGE" -name '*.gz' -print0 | xargs -0 -n16 -P4 gzip -t

# ! -name MANIFEST: without it, find hashes the half-written MANIFEST the
# redirect just created and verification fails against itself (run 1 did).
( cd "$STAGE" && find . -type f ! -name MANIFEST -exec sha256sum {} + > MANIFEST )

# ── Tar + hash ──────────────────────────────────────────────────────────────
tar -C "$STAGE" -cf "$TAR" .
TARHASH=$(sha256sum "$TAR" | awk '{print $1}')
printf '%s  %s\n' "$TARHASH" "$TS.tar" > "$TAR.sha256"
du -sh "$TAR"

# ── Upload, free stage, verify by re-download ───────────────────────────────
smb "put $TAR $TS.tar; put $TAR.sha256 $TS.tar.sha256"
rm -rf "$STAGE"

VERIFY="$BACKUP_ROOT/verify-$TS.tar"
smb "get $TS.tar $VERIFY"
GOT=$(sha256sum "$VERIFY" | awk '{print $1}')
rm -f "$VERIFY"
[ "$GOT" = "$TARHASH" ] || { echo "FAIL: remote artifact hash mismatch"; exit 1; }
echo "remote artifact verified ($TARHASH)"

# ── Prune remote to RETAIN_REMOTE (ISO timestamps sort lexically) ───────────
mapfile -t REMOTE < <(smb "ls *.tar" 2>/dev/null | awk '$1 ~ /\.tar$/ {print $1}' | sort -r)
for ((i=RETAIN_REMOTE; i<${#REMOTE[@]}; i++)); do
  echo "pruning remote ${REMOTE[$i]}"
  smb "del ${REMOTE[$i]}; del ${REMOTE[$i]}.sha256" || true
done

find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'stage-*' -exec rm -rf {} +

echo "backup complete: $TS ($HOST -> $SHARE_UNC)"
