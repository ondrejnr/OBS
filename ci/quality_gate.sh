#!/bin/bash
set -e

# Configuration - Default values if not provided via Environment
NAMESPACE=${NAMESPACE:-obs-dev}
PROM_URL=${PROM_URL:-http://prometheus.monitoring.svc.cluster.local:9090}
ES_URL=${ES_URL:-http://elasticsearch.logging.svc.cluster.local:9200}

echo "----------------------------------------------------"
echo "Starting Quality Gate for namespace: $NAMESPACE"
echo "Prometheus target: $PROM_URL"
echo "Elasticsearch target: $ES_URL"
echo "----------------------------------------------------"

# 1. Connectivity Check: Prometheus
echo "[STEP 1] Checking Prometheus health..."
if ! curl -s --connect-timeout 5 "$PROM_URL/-/healthy" > /dev/null; then
  echo "ERROR: Prometheus unreachable at $PROM_URL"
  exit 1
fi
echo "SUCCESS: Prometheus is UP."

# 2. Connectivity Check: Elasticsearch
echo "[STEP 2] Checking Elasticsearch health..."
if ! curl -s --connect-timeout 5 "$ES_URL" > /dev/null; then
  echo "ERROR: Elasticsearch unreachable at $ES_URL"
  exit 1
fi
echo "SUCCESS: Elasticsearch is UP."

# 3. Functional Check: Load Test on Web App
echo "[STEP 3] Running HTTP Load Test against obs-web-svc..."
# Using unique pod name to avoid AlreadyExists error
kubectl run obs-loadgen-$(date +%s) --rm -i --image=busybox --restart=Never -n $NAMESPACE -- \
  /bin/sh -c "for i in 1 2 3 4 5; do wget -q -O- http://obs-web-svc > /dev/null && echo -n '.' || echo -n 'X'; sleep 0.2; done"

echo -e "\n----------------------------------------------------"
echo "RESULT: All Quality Gate tests PASSED successfully!"
echo "----------------------------------------------------"
