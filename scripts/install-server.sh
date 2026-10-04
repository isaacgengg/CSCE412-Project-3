#!/usr/bin/env bash
# Project 3 - install the K3s server (control plane + schedulable workload node)
# Run on the k3s-server instance.
set -euo pipefail

K3S_VERSION="${K3S_VERSION:-v1.36.5+k3s1}"   # pinned; the agent must match
NODE_NAME="${NODE_NAME:-k3s-server}"

imds() {  # instance metadata lookup (IMDSv2)
  local token
  token=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
            -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
  curl -sS -H "X-aws-ec2-metadata-token: ${token}" \
       "http://169.254.169.254/latest/meta-data/$1"
}
PRIVATE_IP="$(imds local-ipv4)"

echo "[1/5] K3s configuration (node-ip ${PRIVATE_IP})"
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml >/dev/null <<CFG
node-name: ${NODE_NAME}
node-ip: ${PRIVATE_IP}
disable:
  - traefik
  - servicelb
CFG

echo "[2/5] Installing K3s ${K3S_VERSION} as a server"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server

echo "[3/5] kubeconfig for ${USER}"
mkdir -p "${HOME}/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"
grep -q 'KUBECONFIG=' "${HOME}/.bashrc" || \
  echo 'export KUBECONFIG="$HOME/.kube/config"' >> "${HOME}/.bashrc"
export KUBECONFIG="${HOME}/.kube/config"

echo "[4/5] Waiting for ${NODE_NAME} to register and become Ready"
until kubectl get node "${NODE_NAME}" >/dev/null 2>&1; do sleep 2; done
kubectl wait --for=condition=Ready "node/${NODE_NAME}" --timeout=180s
kubectl get nodes -o wide

echo "[5/5] Join details for the worker"
echo "  server private IP : ${PRIVATE_IP}"
echo "  join token        : sudo cat /var/lib/rancher/k3s/server/node-token"
echo
echo "Next, on k3s-worker:"
echo "  ./scripts/install-agent.sh ${PRIVATE_IP} '<join-token>'"
