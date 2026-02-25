#!/bin/bash
set -e

echo "----------------------------------------------------"
echo "OBS QUALITY GATE - VERSION 22 (Host-Based Testing)"
echo "----------------------------------------------------"

# 1. Discover Service IPs
echo "[INFO] Discovering service endpoints..."
PROM_IP=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.clusterIP}')
ES_IP=$(kubectl get svc elasticsearch -n logging -o jsonpath='{.spec.clusterIP}')
WEB_IP=$(kubectl get svc obs-web-svc -n obs-dev -o jsonpath='{.spec.clusterIP}')

PROM_URL="http://$PROM_IP:9090"
ES_URL="http://$ES_IP:9200"
WEB_URL="http://$WEB_IP:80"

echo "Prometheus found at: $PROM_URL"
echo "Elasticsearch found at: $ES_URL"
echo "Web Service found at: $WEB_URL"

# 2. Prometheus Check
echo "[STEP 1] Testing Prometheus..."
if ! curl -s --connect-timeout 5 "$PROM_URL/-/healthy" > /dev/null; then
  echo "ERROR: Prometheus unreachable."
  exit 1
fi
echo "SUCCESS: Prometheus is UP."

# 3. Elasticsearch Check
echo "[STEP 2] Testing Elasticsearch..."
if ! curl -s --connect-timeout 5 "$ES_URL" > /dev/null; then
  echo "ERROR: Elasticsearch unreachable."
  exit 1
fi
echo "SUCCESS: Elasticsearch is UP."

# 4. Load Test (Executed directly from VM host to save CPU)
echo "[STEP 3] Running Load Test against $WEB_URL..."
for i in {1..10}; do
  if curl -s --connect-timeout 2 "$WEB_URL" > /dev/null; then
    echo -n "."
  else
    echo -n "X"
    exit 1
  fi
  sleep 0.1
done

echo -e "\n----------------------------------------------------"
echo "FINAL RESULT: ALL TESTS PASSED (V22)"
echo "----------------------------------------------------"
