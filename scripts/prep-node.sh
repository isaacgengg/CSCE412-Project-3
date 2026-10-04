#!/usr/bin/env bash
# Project 3 - base preparation for a K3s node (Ubuntu 24.04 LTS on EC2)
# Usage: ./scripts/prep-node.sh server|worker
set -euo pipefail

ROLE="${1:?usage: prep-node.sh server|worker}"
case "${ROLE}" in
  server) NEW_HOSTNAME=k3s-server ;;
  worker) NEW_HOSTNAME=k3s-worker ;;
  *) echo "role must be 'server' or 'worker'" >&2; exit 1 ;;
esac

echo "[1/3] Base packages"
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates git netcat-openbsd tree

echo "[2/3] Hostname -> ${NEW_HOSTNAME} (kept across stop/start)"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"
# cloud-init would otherwise restore the ip-172-31-x-x name on the next boot
echo 'preserve_hostname: true' | sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg >/dev/null
grep -q "127.0.1.1 ${NEW_HOSTNAME}" /etc/hosts || \
  echo "127.0.1.1 ${NEW_HOSTNAME}" | sudo tee -a /etc/hosts >/dev/null

echo "[3/3] Host firewall state"
echo "  $(sudo ufw status | head -1)"

echo "Done. Private IPv4: $(hostname -I | awk '{print $1}')  (log out and back in to see the new prompt)"
