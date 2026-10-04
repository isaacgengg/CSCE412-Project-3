#!/usr/bin/env bash
# Project 3 - save a timestamped evidence snapshot
# Usage: ./scripts/capture.sh <label>      e.g. ./scripts/capture.sh exp2-worker-down
set -uo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

LABEL="${1:?usage: capture.sh <label>}"
mkdir -p evidence
OUT="evidence/$(date -u +%Y%m%dT%H%M%SZ)-${LABEL}.txt"

CMDS=(
  "kubectl get nodes -o wide"
  "kubectl get node k3s-worker -o jsonpath='{range .spec.taints[*]}{.key}:{.effect}{\"\\n\"}{end}'"
  "kubectl get deployment csce412-demo"
  "kubectl get replicaset -l app=csce412-demo"
  "kubectl get pods -l app=csce412-demo -o wide"
  "kubectl get events --sort-by=.lastTimestamp | tail -n 25"
)

{
  echo "### ${LABEL} - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  for c in "${CMDS[@]}"; do
    echo; echo "\$ ${c}"; eval "${c}" 2>&1
  done
} | tee "${OUT}"
echo; echo "saved -> ${OUT}"
