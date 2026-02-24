#!/bin/bash
set -e

echo "=== FLUX SYSTEM STATUS ==="
flux check

echo -e "\n=== GIT SOURCES ==="
flux get sources git

echo -e "\n=== KUSTOMIZATIONS ==="
flux get kustomizations

echo -e "\n=== OBS PODS ==="
kubectl get pods -n obs-dev -n obs-staging -n obs-prod

echo -e "\n=== OBS SERVICES ==="
kubectl get svc -n obs-dev -n obs-staging -n obs-prod

echo -e "\n=== RESOURCE USAGE ==="
kubectl top nodes

echo -e "\n=== RECENT FLUX EVENTS ==="
kubectl get events -n flux-system --sort-by='.lastTimestamp' | tail -15
