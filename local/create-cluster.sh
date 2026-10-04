#!/usr/bin/env bash
# Project 3 - local reference cluster: K3s nodes running as Docker containers (k3d)
# Run from WSL2 / Linux / macOS with Docker running.
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=csce412
# Same K3s release as the AWS build, so both environments run identical Kubernetes
K3S_IMAGE="${K3S_IMAGE:-rancher/k3s:v1.36.5-k3s1}"

echo "[1/4] Creating k3d cluster '${CLUSTER}' (1 server + 1 agent, ${K3S_IMAGE})"
k3d cluster create "${CLUSTER}" \
  --image "${K3S_IMAGE}" \
  --servers 1 \
  --agents 1 \
  --wait \
  --k3s-arg "--disable=traefik@server:*" \
  --k3s-arg "--disable=servicelb@server:*"

echo "[2/4] Nodes"
kubectl get nodes -o wide

echo "[3/4] Labelling the agent as a worker"
kubectl label node "k3d-${CLUSTER}-agent-0" node-role.kubernetes.io/worker=worker --overwrite

echo "[4/4] Deploying the reference application"
kubectl apply -f k8s/csce412-deployment.yaml
kubectl rollout status deployment/csce412-demo --timeout=180s
kubectl get pods -o wide
