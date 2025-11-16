#!/bin/bash
set -e

echo "================================================"
echo "PostgreSQL Production Server Provisioning"
echo "================================================"

# [1/6] Update system
echo "[1/6] Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# [2/6] Install PostgreSQL 17 and dependencies
echo "[2/6] Installing PostgreSQL 17..."
apt-get install -y wget gnupg2 curl ca-certificates lsb-release

# Add PostgreSQL APT repo
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/postgresql.gpg > /dev/null

apt-get update
apt-get install -y postgresql-17 postgresql-contrib-17

# [3/6] Configure PostgreSQL
echo "[3/6] Configuring PostgreSQL..."
systemctl stop postgresql

PG_CONF="/etc/postgresql/17/main/postgresql.conf"
PG_HBA="/etc/postgresql/17/main/pg_hba.conf"

# Backup original configs
cp $PG_CONF ${PG_CONF}.backup
cp $PG_HBA ${PG_HBA}.backup

# postgresql.conf updates
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
sed -i "s/max_connections = 100/max_connections = 200/" $PG_CONF
sed -i "s/shared_buffers = 128MB/shared_buffers = 1GB/" $PG_CONF
sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 3GB/" $PG_CONF
sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 256MB/" $PG_CONF
sed -i "s/#checkpoint_completion_target = 0.9/checkpoint_completion_target = 0.9/" $PG_CONF
sed -i "s/#wal_buffers = -1/wal_buffers = 16MB/" $PG_CONF
sed -i "s/#default_statistics_target = 100/default_statistics_target = 100/" $PG_CONF

# pg_hba.conf updates
cat >> $PG_HBA << EOF

# Custom configuration for production access
host    all             all             0.0.0.0/0               scram-sha-256
EOF

# [4/6] Start and enable PostgreSQL 17
echo "[4/6] Starting PostgreSQL 17..."
systemctl enable postgresql@17-main
systemctl start postgresql@17-main

# [5/6] Set postgres user password (placeholder)
echo "[5/6] Setting postgres user password..."
TEMP_PASS="ChangeThisPassword_$(date +%s)"
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$TEMP_PASS';"

# [6/6] Create backup directory
echo "[6/6] Creating backup directory..."
mkdir -p /var/lib/postgresql/backups
chown postgres:postgres /var/lib/postgresql/backups

echo "================================================"
echo "PostgreSQL provisioning complete!"
echo "================================================"
echo "PostgreSQL version:"
sudo -u postgres psql -c "SELECT version();"
echo ""
echo "TEMPORARY PASSWORD for postgres: $TEMP_PASS"
echo "IMPORTANT: Change the postgres password immediately!"
echo "================================================"