# provision-worker.sh
#!/bin/bash
set -e

echo "[${HOSTNAME}] Installing k3s agent..."

SECRETS_DIR="/vagrant/secrets"
while [ ! -f "$SECRETS_DIR/node-token" ] || [ ! -f "$SECRETS_DIR/master-ip" ]; do
  echo "Waiting for master node to write join info..."
  sleep 2
done

NODE_TOKEN=$(cat $SECRETS_DIR/node-token)
MASTER_IP=$(cat $SECRETS_DIR/master-ip)

curl -sfL https://get.k3s.io | K3S_URL="https://$MASTER_IP:6443" K3S_TOKEN="$NODE_TOKEN" sh -

echo "[${HOSTNAME}] Joined cluster."