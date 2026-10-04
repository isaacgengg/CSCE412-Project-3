#!/usr/bin/env bash
# Project 3 - install the K3s agent (worker) and join it to the server
# Usage: ./scripts/install-agent.sh <server-private-ip> '<join-token>'
set -euo pipefail

SERVER_IP="${1:?usage: install-agent.sh <server-private-ip> '<join-token>'}"
JOIN_TOKEN="${2:?usage: install-agent.sh <server-private-ip> '<join-token>'}"
K3S_VERSION="${K3S_VERSION:-v1.36.5+k3s1}"   # must match the server
NODE_NAME="${NODE_NAME:-k3s-worker}"

imds() {  # instance metadata lookup (IMDSv2)
  local token
  token=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
            -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
  curl -sS -H "X-aws-ec2-metadata-token: ${token}" \
       "http://169.254.169.254/latest/meta-data/$1"
}
PRIVATE_IP="$(imds local-ipv4)"

echo "[1/4] Pre-flight: K3s API reachable at ${SERVER_IP}:6443?"
if ! nc -z -w 5 "${SERVER_IP}" 6443; then
  echo "  FAILED - check the TCP 6443 rule in k3s-cluster-sg and that K3s is running on the server" >&2
  exit 1
fi
echo "  OK"

echo "[2/4] K3s configuration (node-ip ${PRIVATE_IP})"
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml >/dev/null <<CFG
node-name: ${NODE_NAME}
node-ip: ${PRIVATE_IP}
CFG

echo "[3/4] Installing K3s ${K3S_VERSION} as an agent of https://${SERVER_IP}:6443"
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_VERSION}" \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${JOIN_TOKEN}" \
  sh -

echo "[4/4] Agent service"
for _ in $(seq 1 30); do
  systemctl is-active --quiet k3s-agent && break
  sleep 2
done
echo "  k3s-agent: $(systemctl is-active k3s-agent || true)"
echo
echo "On k3s-server:  kubectl get nodes -o wide   (k3s-worker should report Ready within ~30 s)"
