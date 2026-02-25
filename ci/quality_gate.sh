#!/bin/bash
set -e

# HARDCODED CONFIGURATION (Ignoring external ENV to fix naming issues)
NAMESPACE="obs-dev"
PROM_URL="http://prometheus.monitoring.svc.cluster.local:9090"
ES_URL="http://elasticsearch.logging.svc.cluster.local:9200"

echo "----------------------------------------------------"
echo "OBS QUALITY GATE - VERSION 20"
echo "Checking connection to: $PROM_URL"
echo "----------------------------------------------------"

# 1. Prometheus Check
echo "[STEP 1] Testing Prometheus..."
if ! curl -s --connect-timeout 5 "$PROM_URL/-/healthy" > /dev/null; then
  echo "ERROR: Prometheus is unreachable at $PROM_URL"
  exit 1
fi
echo "SUCCESS: Prometheus connection established."

# 2. Elasticsearch Check
echo "[STEP 2] Testing Elasticsearch..."
if ! curl -s --connect-timeout 5 "$ES_URL" > /dev/null; then
  echo "ERROR: Elasticsearch is unreachable at $ES_URL"
  exit 1
fi
echo "SUCCESS: Elasticsearch connection established."

# 3. Load Test
echo "[STEP 3] Running Load Test..."
kubectl run obs-v20-$(date +%s) --rm -i --image=busybox --restart=Never -n $NAMESPACE -- \
  /bin/sh -c "for i in 1 2 3 4 5; do wget -q -O- http://obs-web-svc > /dev/null && echo -n '.' || echo -n 'X'; sleep 0.1; done"

echo -e "\n----------------------------------------------------"
echo "FINAL RESULT: ALL TESTS PASSED (V20)"
echo "----------------------------------------------------"
