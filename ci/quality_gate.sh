#!/bin/bash
set -e

# Funkcia na inteligentné čakanie na službu a jej pripravenosť
check_ready() {
    local svc=$1
    local ns=$2
    local port=$3
    local endpoint=$4
    local label=$5

    echo "--- Kontrola: $label ($svc v $ns) ---"
    for i in {1..40}; do
        # Získanie ClusterIP
        local ip=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        
        if [ -n "$ip" ] && [ "$ip" != "<none>" ]; then
            # Skúška pripojenia cez curl
            if curl -sSf --connect-timeout 2 "http://$ip:$port$endpoint" > /dev/null 2>&1; then
                echo "✅ $label je pripravený (IP: $ip)"
                return 0
            fi
        fi
        echo "Čakám na $label... ($i/40)"
        sleep 5
    done
    echo "❌ CHYBA: $label nie je dostupný po limite!"
    return 1
}

echo "----------------------------------------------------"
echo "OBS FULL PIPELINE QUALITY GATE - VERSION 26"
echo "----------------------------------------------------"

# 1. Kontrola Docker Hub obrazov (či pody vôbec bežia, nie sú v ImagePullBackOff)
echo "[STEP 1] Kontrola stavu podov (Docker Hub / Images)..."
if kubectl get pods -A | grep -E "ImagePullBackOff|ErrImagePull|CrashLoopBackOff"; then
    echo "❌ Zistené chyby pri sťahovaní obrazov alebo pády podov!"
    exit 1
else
    echo "✅ Pody nevykazujú chyby sťahovania."
fi

# 2. Kontrola Monitoringu (Grafana - namiesto chýbajúceho Promethea)
check_ready "grafana" "monitoring" "3000" "/api/health" "Monitoring (Grafana)"

# 3. Kontrola Loggingu (Elasticsearch)
check_ready "elasticsearch" "logging" "9200" "/_cluster/health?local=true" "Logging (Elasticsearch)"

# 4. Kontrola Web Aplikácie (Staging)
check_ready "obs-web-svc" "obs-staging" "80" "/" "OBS Web Application"

echo "----------------------------------------------------"
echo "VŠETKY OBS SLUŽBY SÚ OK - PIPELINE ÚSPEŠNÁ"
echo "----------------------------------------------------"
