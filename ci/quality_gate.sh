#!/bin/bash
set -e

# Function to wait for Service IP and check readiness
check_service() {
    local svc=$1
    local ns=$2
    local port=$3
    local endpoint=$4
    local ip=""

    echo "--- Checking $svc in $ns ---"
    for i in {1..30}; do
        ip=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        if [ -n "$ip" ] && [ "$ip" != "<none>" ]; then
            echo "Found IP for $svc: $ip. Testing endpoint..."
            if curl -sSf --connect-timeout 5 "http://$ip:$port$endpoint" > /dev/null; then
                echo "✅ Service $svc is READY"
                return 0
            fi
        fi
        echo "Waiting for $svc ($i/30)..."
        sleep 5
    done
    echo "❌ Timeout: Service $svc not ready after 150 seconds"
    exit 1
}

echo "----------------------------------------------------"
echo "OBS FULL STACK QUALITY GATE - V25 (AUTO-DEPLOY)"
echo "----------------------------------------------------"

# 1. Check Grafana (Monitoring)
check_service "grafana" "monitoring" "3000" "/api/health"

# 2. Check Elasticsearch (Logging)
check_service "elasticsearch" "logging" "9200" "/_cluster/health?local=true"

# 3. Check OBS Web App (Staging)
check_service "obs-web-svc" "obs-staging" "80" "/"

echo "----------------------------------------------------"
echo "SUCCESS: All OBS services are healthy!"
echo "----------------------------------------------------"
