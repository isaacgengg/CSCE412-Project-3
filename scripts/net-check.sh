#!/usr/bin/env bash
# Project 3 - layer-by-layer connectivity check toward the other node
# Usage: ./scripts/net-check.sh <peer-private-ip>
# UDP 8472 (Flannel VXLAN) cannot be probed with nc; verify.sh proves it
# with a real pod-to-pod request across nodes.
set -uo pipefail
PEER="${1:?usage: net-check.sh <peer-private-ip>}"

probe() {  # probe <port> <label>
  local out
  if out=$(nc -vz -w 3 "${PEER}" "$1" 2>&1); then
    printf '  %-10s %-28s OPEN\n' "$1/tcp" "$2"
  elif grep -qi 'refused' <<<"${out}"; then
    printf '  %-10s %-28s REFUSED  (host reached, nothing listening)\n' "$1/tcp" "$2"
  else
    printf '  %-10s %-28s TIMEOUT  (dropped by security group / firewall)\n' "$1/tcp" "$2"
  fi
}

echo "=== net-check $(hostname) -> ${PEER} - $(date -u '+%Y-%m-%d %H:%M UTC') ==="

echo; echo "--- This node ---"
echo "  hostname     $(hostname)"
echo "  private IP   $(hostname -I | awk '{print $1}')"
echo "  default gw   $(ip route show default | awk '{print $3; exit}')"

echo; echo "--- ICMP ---"
if ping -c 3 -W 2 "${PEER}" >/dev/null 2>&1; then
  echo "  ping         OK"
else
  echo "  ping         FAILED (ICMP may be filtered - not conclusive on its own)"
fi

echo; echo "--- TCP ---"
probe 22    "SSH"
probe 6443  "K3s API (server only)"
probe 10250 "kubelet (after K3s install)"

echo; echo "--- Host firewall ---"
echo "  $(sudo ufw status | head -1)"

echo; echo "--- Local listeners (K3s) ---"
sudo ss -lntup | awk 'NR==1 || /k3s|containerd/' | head -12
