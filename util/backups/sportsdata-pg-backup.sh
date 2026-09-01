#!/usr/bin/env bash
# Nightly PostgreSQL backup — runs on sdprod-data-01 as root (systemd timer).
#
# Transport is smbclient (userspace SMB3), NOT a kernel cifs mount: on
# 2026-09-01 the kernel client silently corrupted the two largest archives
# (3.5G and 13G) during cp — checksums caught it — which matches a long
# lineage of kernel-cifs large-file corruption bugs. curl smb:// was ruled
# out too (SMB1-only; Windows refuses it). smbclient is a different code
# path entirely and every run is verified by re-downloading the artifact
# and comparing hashes, so a transport regression can never pass silently.
#
# Each run produces ONE artifact: <UTC timestamp>.tar (+ .sha256 sidecar)
# under sdprod-backups/<hostname>/ on Bender. Inside the tar:
#   globals.sql   - roles/tablespaces (pg_dumpall --globals-only)
#   <db>.dump     - custom-format archive per database (individually
#                   pg_restore-able; -Fc is compressed, tar adds no gzip)
#   MANIFEST      - per-file sha256, written before tarring
#
# Restore: tar -xf <ts>.tar; psql -f globals.sql (bare server); then
#          pg_restore -d <db> --clean --if-exists <db>.dump
#
# Retention: newest tar locally; RETAIN_REMOTE tars on the share.

set -euo pipefail

CONF=/etc/sportsdata-backup/config
# shellcheck source=/dev/null
source "$CONF" # SHARE_UNC, SMB_CREDS, BACKUP_ROOT, RETAIN_REMOTE

HOST=$(hostname)
TS=$(date -u +%Y-%m-%dT%H%M%SZ)
STAGE="$BACKUP_ROOT/stage-$TS"
TAR="$BACKUP_ROOT/$TS.tar"

smb() { smbclient "$SHARE_UNC" -A "$SMB_CREDS" -D "$HOST" -c "$1"; }

exec 9>/run/sportsdata-backup.lock
flock -n 9 || { echo "previous backup still running; skipping"; exit 0; }

echo "backup starting: $TS"
mkdir -p "$STAGE"

# ── Dump (stdout redirects: pg_dump runs as postgres, files land root-owned;
#    -f failed on the first run because postgres cannot write into the
#    root-owned 0700 staging dir) ───────────────────────────────────────────
sudo -u postgres pg_dumpall --globals-only > "$STAGE/globals.sql"

mapfile -t DBS < <(sudo -u postgres psql -Atc \
  "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'")

for db in "${DBS[@]}"; do
  echo "dumping $db"
  sudo -u postgres pg_dump -Fc --no-password -d "$db" > "$STAGE/$db.dump.tmp"
  # pg_restore --list parses the whole TOC — a truncated archive fails
  # tonight, not on the day a restore is needed.
  pg_restore --list "$STAGE/$db.dump.tmp" > /dev/null
  mv "$STAGE/$db.dump.tmp" "$STAGE/$db.dump"
done

( cd "$STAGE" && sha256sum ./*.dump globals.sql > MANIFEST )

# ── Tar + hash ──────────────────────────────────────────────────────────────
tar -C "$STAGE" -cf "$TAR" .
TARHASH=$(sha256sum "$TAR" | awk '{print $1}')
printf '%s  %s\n' "$TARHASH" "$TS.tar" > "$TAR.sha256"
du -sh "$TAR"

# ── Upload ──────────────────────────────────────────────────────────────────
smb "put $TAR $TS.tar; put $TAR.sha256 $TS.tar.sha256"

# Stage no longer needed; free it before the verify re-download so the
# verify's disk peak stays bounded (matters on the mongo box, kept
# symmetric here).
rm -rf "$STAGE"

# ── Verify: re-download the artifact and compare hashes. This re-reads
#    server-side bytes through a fresh session — the strongest practical
#    proof the share holds exactly what was dumped. ─────────────────────────
VERIFY="$BACKUP_ROOT/verify-$TS.tar"
smb "get $TS.tar $VERIFY"
GOT=$(sha256sum "$VERIFY" | awk '{print $1}')
rm -f "$VERIFY"
[ "$GOT" = "$TARHASH" ] || { echo "FAIL: remote artifact hash mismatch"; exit 1; }
echo "remote artifact verified ($TARHASH)"

# ── Prune ───────────────────────────────────────────────────────────────────
# Remote: keep newest RETAIN_REMOTE tars (ISO timestamps sort lexically).
mapfile -t REMOTE < <(smb "ls *.tar" 2>/dev/null | awk '$1 ~ /\.tar$/ {print $1}' | sort -r)
for ((i=RETAIN_REMOTE; i<${#REMOTE[@]}; i++)); do
  echo "pruning remote ${REMOTE[$i]}"
  smb "del ${REMOTE[$i]}; del ${REMOTE[$i]}.sha256" || true
done

# Local: keep only the artifact just verified remotely.
find "$BACKUP_ROOT" -maxdepth 1 -name '*.tar' ! -name "$TS.tar" -delete
find "$BACKUP_ROOT" -maxdepth 1 -name '*.tar.sha256' ! -name "$TS.tar.sha256" -delete
find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'stage-*' ! -name "stage-$TS" -exec rm -rf {} +

echo "backup complete: $TS ($HOST -> $SHARE_UNC)"
