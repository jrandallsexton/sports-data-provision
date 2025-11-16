#!/bin/bash
set -e

echo "[sd0] Installing k3s control plane..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

echo "[sd0] Waiting for node-token to become available..."
TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
while [ ! -f "$TOKEN_FILE" ]; do
  sleep 1
done

NODE_TOKEN=$(cat "$TOKEN_FILE")

# More robust IP detection: grabs the first non-loopback IPv4 address
MASTER_IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i !~ /^127\./) {print $i; exit}}')

if [[ -z "$MASTER_IP" ]]; then
  echo "[sd0] ❌ Could not determine master IP. Exiting."
  exit 1
fi

echo "[sd0] Writing token and IP to /vagrant/secrets..."
mkdir -p /vagrant/secrets
echo "$NODE_TOKEN" > /vagrant/secrets/node-token
echo "$MASTER_IP" > /vagrant/secrets/master-ip

echo "[sd0] ✅ Cluster initialized. Control plane ready."