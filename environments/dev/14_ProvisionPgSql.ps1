# =========================
# Script — Install & Configure PostgreSQL on sportdeets-pgsql-dev-eus2
# =========================

# 1) Load secrets
if (-not $env:SPORTDEETS_SECRETS_PATH) { throw "ERROR: Set SPORTDEETS_SECRETS_PATH first." }
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# 2) Fixed identifiers (no guesswork)
$subscriptionId    = $script:subscriptionIdSecondary
$resourceGroupName = "rg-sportdeets-dev2-eus2"
$vmName            = "sportdeets-pgsql-dev-eus2"

# 3) Pull required values
$pgAdminPassword   = $script:pgPasswordDev
$appIntSubnetCidr  = "10.50.10.0/26"

# 4) Azure context
az account set --subscription $subscriptionId | Out-Null

# 5) Resolve VM private IP
$vmPrivIp = az vm show -g $resourceGroupName -n $vmName -d --query "privateIps" -o tsv
if (-not $vmPrivIp) { throw "Could not resolve VM private IP." }

# 6) Build the bash payload (PowerShell interpolates secrets/IP)
$bash = @"
set -euo pipefail

echo "==> Installing PostgreSQL and preparing data disk"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y postgresql postgresql-contrib rsync

LUN_DEV="/dev/disk/azure/scsi1/lun0"
MNT="/var/lib/postgresql"

for i in {1..30}; do
  [ -b "\$LUN_DEV" ] && break
  sleep 2
done
if [ ! -b "\$LUN_DEV" ]; then
  echo "Data disk not found at \$LUN_DEV" >&2
  exit 1
fi

if ! blkid "\$LUN_DEV" >/dev/null 2>&1; then
  mkfs.ext4 -F "\$LUN_DEV"
fi

mkdir -p "\$MNT"
UUID=\$(blkid -s UUID -o value "\$LUN_DEV")
if ! grep -q "\$UUID" /etc/fstab; then
  echo "UUID=\$UUID  \$MNT  ext4  defaults,nofail  0  2" >> /etc/fstab
fi
mount -a
chown -R postgres:postgres "\$MNT"

PG_MAIN_DIR=\$(ls -d /etc/postgresql/*/main | head -n1)
PG_VER=\$(basename \$(dirname "\$PG_MAIN_DIR"))
PG_DATA_DIR="/var/lib/postgresql/\$PG_VER/main"

systemctl stop postgresql || true
if [ -d "\$PG_DATA_DIR" ] && [ ! -d "\$MNT/\$PG_VER/main" ]; then
  rsync -aHAX "\$PG_DATA_DIR/" "\$MNT/\$PG_VER/main/"
fi

# Ensure PG uses the mounted disk
sed -i "s|^#*data_directory *=.*|data_directory = '\$MNT/\$PG_VER/main'|" "\$PG_MAIN_DIR/postgresql.conf"

# Bind to the VM's private IP
sed -i "s/^#*listen_addresses.*/listen_addresses = '$vmPrivIp'/" "\$PG_MAIN_DIR/postgresql.conf"

# Prefer SCRAM
if grep -q "^#*password_encryption" "\$PG_MAIN_DIR/postgresql.conf"; then
  sed -i "s/^#*password_encryption.*/password_encryption = scram-sha-256/" "\$PG_MAIN_DIR/postgresql.conf"
else
  echo "password_encryption = scram-sha-256" >> "\$PG_MAIN_DIR/postgresql.conf"
fi

# Tighten pg_hba.conf
sed -i "/0.0.0.0\\/0/d" "\$PG_MAIN_DIR/pg_hba.conf"
echo "host all all 127.0.0.1/32 scram-sha-256" >> "\$PG_MAIN_DIR/pg_hba.conf"
echo "host all all $appIntSubnetCidr scram-sha-256" >> "\$PG_MAIN_DIR/pg_hba.conf"

systemctl start postgresql

# Set postgres DB user password
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER USER postgres WITH PASSWORD '$pgAdminPassword';"

echo
echo "==> pg_isready:"
pg_isready -h $vmPrivIp -p 5432 || true
echo
echo "==> lsblk:"
lsblk
echo
echo "==> df -h (postgres mount):"
df -h | grep -E "/var/lib/postgresql|Filesystem" || true
echo
echo "==> done."
"@

# 7) Send to VM and run
az vm run-command invoke -g $resourceGroupName -n $vmName --command-id RunShellScript --scripts "$bash"
