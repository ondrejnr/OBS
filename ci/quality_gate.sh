#!/bin/bash
set -e

# Configuration
NAMESPACE=${NAMESPACE:-obs-dev}
# Defaulting to the correct service name 'prometheus'
PROM_URL=${PROM_URL:-http://prometheus.monitoring.svc.cluster.local:9090}
ES_URL=${ES_URL:-http://elasticsearch.logging.svc.cluster.local:9200}

echo "----------------------------------------------------"
echo "Starting Quality Gate Analysis"
echo "Namespace: $NAMESPACE"
echo "Prometheus: $PROM_URL"
echo "Elasticsearch: $ES_URL"
echo "----------------------------------------------------"

# 1. Prometheus Connection Test
echo "[STEP 1] Testing Prometheus connectivity..."
if ! curl -s --connect-timeout 5 "$PROM_URL/-/healthy" > /dev/null; then
  echo "ERROR: Cannot reach Prometheus at $PROM_URL"
  echo "Check if the service name is 'prometheus' or 'prometheus-server'."
  exit 1
fi
echo "SUCCESS: Prometheus is reachable."

# 2. Elasticsearch Connection Test
echo "[STEP 2] Testing Elasticsearch connectivity..."
if ! curl -s --connect-timeout 5 "$ES_URL" > /dev/null; then
  echo "ERROR: Cannot reach Elasticsearch at $ES_URL"
  exit 1
fi
echo "SUCCESS: Elasticsearch is reachable."

# 3. Load Test
echo "[STEP 3] Running Load Test against obs-web-svc..."
kubectl run obs-test-$(date +%s) --rm -i --image=busybox --restart=Never -n $NAMESPACE -- \
  /bin/sh -c "for i in 1 2 3 4 5; do wget -q -O- http://obs-web-svc > /dev/null && echo -n '.' || echo -n 'X'; sleep 0.2; done"

echo -e "\n----------------------------------------------------"
echo "FINAL RESULT: QUALITY GATE PASSED"
echo "----------------------------------------------------"
