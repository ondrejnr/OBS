# OBS - Observability Delivery Platform

GitOps + Quality Gate delivery platform for Kubernetes deployments.

**Uses existing cluster services:**
- Nginx (web/load balancer) 
- Prometheus (metrics)
- Elasticsearch + Kibana (logs)
- Fluentd (log collection)

**Repository structure:** `infra/`(manifests by env), `app/`(demo source), `ci/`(quality gates)

## Core workflow
1. Developer → push code to `app/` branch
2. CI → build → deploy to `obs-dev` via GitOps  
3. Quality Gates → validate Prometheus metrics + ES logs
4. Auto-promote → staging → prod (if gates pass)

## Quality Gates (measured automatically)
| Metric | Limit | Source |
|--------|-------|---------|
| p95 Latency | < 300ms | Prometheus |
| Error Rate | < 1% | Prometheus |
| 5xx Errors | 0/min | Prometheus |
| Suspicious Logs | 0 | Elasticsearch |

## Quick Start
Last connection check: Wed Feb 25 02:04:37 UTC 2026
