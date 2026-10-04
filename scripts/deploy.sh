#!/usr/bin/env bash
# Project 3 - label the worker and deploy the application (run on k3s-server)
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
WORKER="${WORKER:-k3s-worker}"

echo "[1/4] Labelling ${WORKER} with the worker role"
kubectl label node "${WORKER}" node-role.kubernetes.io/worker=worker --overwrite
kubectl get nodes

echo "[2/4] Applying the Deployment (unchanged from the local reference)"
kubectl apply -f k8s/csce412-deployment.yaml
kubectl rollout status deployment/csce412-demo --timeout=180s

echo "[3/4] Applying the NodePort Service"
kubectl apply -f k8s/csce412-service.yaml

echo "[4/4] Placement"
kubectl get deployment csce412-demo
kubectl get pods -l app=csce412-demo -o wide
