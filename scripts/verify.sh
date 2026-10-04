#!/usr/bin/env bash
# Project 3 - end-to-end cluster verification (run on k3s-server)
set -uo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

APP=csce412-demo
WORKER=k3s-worker
NODEPORT=30080
pass=0; fail=0; notes=0

ok()      { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
bad()     { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
note()    { printf '  \033[33mNOTE\033[0m  %s\n' "$1"; notes=$((notes+1)); }
section() { printf '\n--- %s ---\n' "$1"; }

echo "=== Project 3 verification - $(date -u '+%Y-%m-%d %H:%M UTC') ==="

section "Versions"
k3s --version | head -1
kubectl version 2>/dev/null | grep -E 'Client|Server'

section "Nodes"
kubectl get nodes -o wide
ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)
[ "${ready}" -eq 2 ] && ok "2 of 2 nodes Ready" || bad "expected 2 Ready nodes, found ${ready}"
role=$(kubectl get node "${WORKER}" -o jsonpath='{.metadata.labels.node-role\.kubernetes\.io/worker}' 2>/dev/null)
[ "${role}" = "worker" ] && ok "${WORKER} carries the worker role label" \
                         || bad "${WORKER} is missing node-role.kubernetes.io/worker"

section "Cluster networking (Flannel VXLAN)"
kubectl get nodes -o custom-columns='NODE:.metadata.name,INTERNAL-IP:.status.addresses[0].address,POD-CIDR:.spec.podCIDR'
cidrs=$(kubectl get nodes -o jsonpath='{range .items[*]}{.spec.podCIDR}{"\n"}{end}' | sort -u | grep -c .)
[ "${cidrs}" -eq 2 ] && ok "each node owns a distinct pod subnet" || bad "pod CIDRs missing or duplicated"

section "System pods (kube-system)"
kubectl get pods -n kube-system -o wide
notrunning=$(kubectl get pods -n kube-system --no-headers | awk '$3!="Running" && $3!="Completed"' | wc -l)
[ "${notrunning}" -eq 0 ] && ok "all kube-system pods Running" || bad "${notrunning} kube-system pod(s) not Running"
withmetrics=$(kubectl top nodes --no-headers 2>/dev/null | grep -vc unknown)
if [ "${withmetrics:-0}" -eq 2 ]; then
  ok "metrics-server reads both kubelets (TCP 10250)"
else
  note "kubectl top nodes incomplete - allow ~60 s after start, otherwise check TCP 10250"
fi

section "Application"
kubectl get deployment "${APP}"
kubectl get pods -l app="${APP}" -o wide
avail=$(kubectl get deployment "${APP}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "${avail:-0}" -eq 2 ] && ok "Deployment ${APP}: 2/2 replicas available" \
                        || bad "Deployment ${APP}: ${avail:-0}/2 replicas available"
spread=$(kubectl get pods -l app="${APP}" --field-selector=status.phase=Running \
          -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | grep -c .)
if [ "${spread}" -eq 2 ]; then
  ok "replicas spread across both nodes (preferred anti-affinity)"
else
  note "both replicas on one node - expected after Experiments 2-3, not at baseline"
fi

section "Pod-to-pod traffic"
mapfile -t PODS < <(kubectl get pods -l app="${APP}" --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name} {.status.podIP} {.spec.nodeName}{"\n"}{end}')
if [ "${#PODS[@]}" -ge 2 ]; then
  read -r p1 ip1 n1 <<<"${PODS[0]}"
  read -r p2 ip2 n2 <<<"${PODS[1]}"
  path="same node"; [ "${n1}" != "${n2}" ] && path="cross-node via VXLAN"
  if kubectl exec "${p1}" -- wget -qO- -T 5 "http://${ip2}/" 2>/dev/null | grep -q 'Welcome to nginx'; then
    ok "${n1}/${ip1} -> ${n2}/${ip2} (${path}): HTTP OK"
  else
    bad "${n1}/${ip1} -> ${n2}/${ip2} (${path}) failed - check UDP 8472"
  fi
else
  bad "fewer than two Running pods to test"
fi

section "Service discovery and NodePort"
kubectl get service "${APP}" -o wide
if [ -n "${p1:-}" ] && kubectl exec "${p1}" -- nslookup "${APP}.default.svc.cluster.local" >/dev/null 2>&1; then
  ok "CoreDNS resolves ${APP}.default.svc.cluster.local"
else
  bad "DNS lookup of ${APP}.default.svc.cluster.local failed"
fi
node_ip=$(hostname -I | awk '{print $1}')
code=$(curl -s -o /dev/null -w '%{http_code}' "http://${node_ip}:${NODEPORT}/")
[ "${code}" = "200" ] && ok "NodePort ${node_ip}:${NODEPORT} -> HTTP ${code}" \
                      || bad "NodePort ${node_ip}:${NODEPORT} -> HTTP ${code}"

section "Summary"
printf '  %d passed, %d failed, %d notes\n' "${pass}" "${fail}" "${notes}"
[ "${fail}" -eq 0 ]
