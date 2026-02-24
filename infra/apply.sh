#!/usr/bin/env bash
set -euo pipefail

# OBS Deploy Helper - deploys manifests by environment
# Usage: ./infra/apply.sh [dev|staging|prod]

ENV="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[OBS] Deploying environment: ${ENV^^}"

case "${ENV}" in
  dev)
    echo "[OBS] Deploying to obs-dev (2 replicas)"
    kubectl apply -f "${SCRIPT_DIR}/environments/dev/"
    ;;
  staging)
    echo "[OBS] Deploying to obs-staging (3 replicas)"
    kubectl apply -f "${SCRIPT_DIR}/environments/staging/"
    ;;
  prod)
    echo "[OBS] Deploying to obs-prod (5 replicas + HPA)"
    kubectl apply -f "${SCRIPT_DIR}/environments/prod/"
    ;;
  *)
    echo "[ERROR] Usage: $0 {dev|staging|prod}"
    exit 1
    ;;
esac

echo "[OBS] Waiting for rollout..."
kubectl rollout status deployment -n "obs-${ENV}" --timeout=120s
echo "[OBS] ✅ ${ENV^^} environment deployed successfully"
