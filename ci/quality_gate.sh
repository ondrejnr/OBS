#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-obs-dev}
PROM_URL=${PROM_URL:-http://localhost:9090}
ES_URL=${ES_URL:-http://localhost:9200}
THRESHOLD_ERROR_RATE=0.01  # 1%
THRESHOLD_LATENCY=500      # ms

echo "[OBS] Running quality gates for $NAMESPACE..."

# Test 1: Prometheus dostupnosť
echo "[OBS] Testing Prometheus connectivity..."
if ! curl -s "$PROM_URL/-/healthy" > /dev/null; then
    echo "[ERROR] Prometheus is not reachable at $PROM_URL"
    exit 1
fi
echo "[OK] Prometheus is healthy"

# Test 2: Elasticsearch dostupnosť
echo "[OBS] Testing Elasticsearch connectivity..."
if ! curl -s "$ES_URL/_cluster/health" > /dev/null; then
    echo "[ERROR] Elasticsearch is not reachable at $ES_URL"
    exit 1
fi
echo "[OK] Elasticsearch is healthy"

# Test 3: Deployment health
echo "[OBS] Checking deployment health..."
READY_REPLICAS=$(kubectl get deployment obs-web -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment obs-web -n $NAMESPACE -o jsonpath='{.spec.replicas}')

if [ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]; then
    echo "[ERROR] Deployment not ready: $READY_REPLICAS/$DESIRED_REPLICAS replicas"
    exit 1
fi
echo "[OK] Deployment ready: $READY_REPLICAS/$DESIRED_REPLICAS replicas"

# Test 4: Load test
echo "[OBS] Running load test..."
SERVICE_IP=$(kubectl get svc obs-web-svc -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')

# Port-forward service
kubectl port-forward -n $NAMESPACE svc/obs-web-svc 8888:80 &
PF_PID=$!
sleep 5

# Jednoduchý load test (10 requestov)
TOTAL_TIME=0
SUCCESS_COUNT=0
for i in {1..10}; do
    START=$(date +%s%3N)
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8888 | grep -q "200"; then
        END=$(date +%s%3N)
        DURATION=$((END - START))
        TOTAL_TIME=$((TOTAL_TIME + DURATION))
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo "Request $i: ${DURATION}ms - OK"
    else
        echo "Request $i: FAILED"
    fi
    sleep 0.5
done

kill $PF_PID || true

# Vyhodnotenie
AVG_LATENCY=$((TOTAL_TIME / 10))
SUCCESS_RATE=$(echo "scale=2; $SUCCESS_COUNT / 10" | bc)

echo "[OBS] Load test results:"
echo "  - Success rate: $SUCCESS_RATE (${SUCCESS_COUNT}/10)"
echo "  - Average latency: ${AVG_LATENCY}ms"

if (( $(echo "$SUCCESS_RATE < 0.95" | bc -l) )); then
    echo "[ERROR] Success rate too low: $SUCCESS_RATE < 0.95"
    exit 1
fi

if [ "$AVG_LATENCY" -gt "$THRESHOLD_LATENCY" ]; then
    echo "[ERROR] Average latency too high: ${AVG_LATENCY}ms > ${THRESHOLD_LATENCY}ms"
    exit 1
fi

# Test 5: Prometheus metrics
echo "[OBS] Checking Prometheus metrics..."
ERROR_RATE=$(curl -s "$PROM_URL/api/v1/query?query=rate(nginx_http_requests_total{status=~\"5..\",namespace=\"$NAMESPACE\"}[5m])" | \
    jq -r '.data.result[0].value[1] // "0"')

echo "  - Error rate: $ERROR_RATE"

if (( $(echo "$ERROR_RATE > $THRESHOLD_ERROR_RATE" | bc -l) )); then
    echo "[ERROR] Error rate too high: $ERROR_RATE > $THRESHOLD_ERROR_RATE"
    exit 1
fi

# Test 6: Elasticsearch logs
echo "[OBS] Checking Elasticsearch logs for errors..."
ERROR_COUNT=$(curl -s "$ES_URL/fluentd-*/_count?q=level:error+AND+kubernetes.namespace_name:$NAMESPACE" | \
    jq -r '.count // 0')

echo "  - Error log count: $ERROR_COUNT"

if [ "$ERROR_COUNT" -gt 10 ]; then
    echo "[WARNING] High error count in logs: $ERROR_COUNT"
    # Nezlyhaj, len warning
fi

echo "[SUCCESS] All quality gates passed for $NAMESPACE!"
exit 0
