#!/usr/bin/env bash
# Project 3 - live view for the experiments (run on k3s-server, Ctrl-C to exit)
# The watch header carries a timestamp, which makes each screenshot self-dating.
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
exec watch -n 2 "kubectl get nodes; echo; kubectl get deployment csce412-demo; echo; kubectl get pods -l app=csce412-demo -o wide"
