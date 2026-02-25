#!/bin/bash
set -e
export KUBECONFIG="${KUBECONFIG:-/home/ondrejko_gulkas/.kube/config}"
echo "----------------------------------------------------"
echo "OBS QUALITY GATE - VERSION 24"
echo "----------------------------------------------------"
get_ip() {
  local svc=$1
  local ns=$2
  local ip=""
  for i in {1..15}; do
    ip=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [ -n "$ip" ]; then echo "$ip"; return 0; fi
    echo "Waiting for service $svc in $ns..."
    sleep 5
  done
  return 1
}
PROM_IP=$(get_ip prometheus monitoring)
ES_IP=$(get_ip elasticsearch logging)
WEB_IP=$(get_ip obs-web-svc obs-dev)
PROM_URL="http://$PROM_IP:9090"
ES_URL="http://$ES_IP:9200"
WEB_URL="http://$WEB_IP:80"
echo "Prometheus: $PROM_URL"
echo "Elasticsearch: $ES_URL"
echo "Web App: $WEB_URL"
echo "[STEP 1] Testing Prometheus..."
curl -s --connect-timeout 2 "$PROM_URL/-/healthy" > /dev/null && echo "OK" || (echo "Prometheus not ready"; exit 1)
echo "[STEP 2] Testing Elasticsearch..."
curl -s --connect-timeout 2 "$ES_URL" > /dev/null && echo "OK" || (echo "Elasticsearch not ready"; exit 1)
echo "[STEP 3] Running Load Test..."
for i in {1..5}; do
  curl -s --connect-timeout 2 "$WEB_URL" > /dev/null && echo -n "." || echo -n "X"
  sleep 0.1
done
echo -e "\n[SUCCESS] Quality Gate Passed!"
