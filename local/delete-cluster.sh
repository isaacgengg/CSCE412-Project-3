#!/usr/bin/env bash
# Project 3 - remove the local reference cluster and its containers
set -euo pipefail
k3d cluster delete csce412
