# CSCE 412 · Project 3 — Two-Node Kubernetes Cluster (K3s on AWS EC2)

Isaac Geng · CSCE 412 Section 500

A K3s server (control plane + workload) and a K3s agent (worker) on two EC2
instances, running a two-replica nginx Deployment, used to demonstrate node
failure, node recovery and pod failure. The full build and test procedure is in
`Project3_Kubernetes_Cluster_Recreation_Guide.pdf`.

## Layout

```
k8s/csce412-deployment.yaml   reference Deployment (2 replicas, preferred anti-affinity) - unchanged
k8s/csce412-service.yaml      NodePort Service (30080) in front of the replicas
local/create-cluster.sh       local reference cluster with k3d (1 server + 1 agent)
local/delete-cluster.sh       remove the local cluster
scripts/prep-node.sh          EC2 node prep: packages, persistent hostname     (both nodes)
scripts/net-check.sh          ICMP / TCP / firewall checks toward the peer     (both nodes)
scripts/install-server.sh     K3s server install, kubeconfig, join details     (server)
scripts/install-agent.sh      K3s agent install and join                       (worker)
scripts/deploy.sh             worker label, Deployment, Service                (server)
scripts/verify.sh             end-to-end PASS/FAIL verification                (server)
scripts/watch.sh              live node/pod view for the experiments           (server)
scripts/capture.sh            timestamped evidence snapshot -> evidence/       (server)
evidence/                     captured output from each experiment
```

## Run order (AWS)

```bash
# both nodes
git clone https://github.com/isaacgengg/CSCE412-Project-3.git project3 && cd project3
./scripts/prep-node.sh server        # or: worker
./scripts/net-check.sh <peer-private-ip>

# server
./scripts/install-server.sh
sudo cat /var/lib/rancher/k3s/server/node-token

# worker
./scripts/install-agent.sh <server-private-ip> '<join-token>'

# server
./scripts/deploy.sh
./scripts/verify.sh
```

K3s is pinned to `v1.36.5+k3s1` on both nodes (override with `K3S_VERSION=...`).
