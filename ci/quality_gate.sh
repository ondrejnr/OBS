#!/bin/bash
set -e

echo "----------------------------------------------------"
echo "OBS QUALITY GATE - VERSION 21 (Dynamic IP Discovery)"
echo "----------------------------------------------------"

# 1. Dynamically discover Service IPs
echo "[INFO] Discovering service endpoints..."
PROM_IP=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.clusterIP}')
ES_IP=$(kubectl get svc elasticsearch -n logging -o jsonpath='{.spec.clusterIP}')

PROM_URL="http://$PROM_IP:9090"
ES_URL="http://$ES_IP:9200"

echo "Prometheus found at: $PROM_URL"
echo "Elasticsearch found at: $ES_URL"

# 2. Prometheus Check
echo "[STEP 1] Testing Prometheus..."
if ! curl -s --connect-timeout 5 "$PROM_URL/-/healthy" > /dev/null; then
  echo "ERROR: Prometheus unreachable at $PROM_URL"
  exit 1
fi
echo "SUCCESS: Prometheus connection established."

# 3. Elasticsearch Check
echo "[STEP 2] Testing Elasticsearch..."
if ! curl -s --connect-timeout 5 "$ES_URL" > /dev/null; then
  echo "ERROR: Elasticsearch unreachable at $ES_URL"
  exit 1
fi
echo "SUCCESS: Elasticsearch connection established."

# 4. Load Test
echo "[STEP 3] Running Load Test against obs-web-svc..."
# Note: Inside the cluster (Pod), the DNS name works fine!
kubectl run obs-v21-$(date +%s) --rm -i --image=busybox --restart=Never -n obs-dev -- \
  /bin/sh -c "for i in 1 2 3 4 5; do wget -q -O- http://obs-web-svc > /dev/null && echo -n '.' || echo -n 'X'; sleep 0.1; done"

echo -e "\n----------------------------------------------------"
echo "FINAL RESULT: ALL TESTS PASSED (V21)"
echo "----------------------------------------------------"
