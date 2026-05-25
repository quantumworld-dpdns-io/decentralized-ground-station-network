# Production Deployment Runbook

## Overview

This runbook covers production deployment of DGSN using Helm and GitOps with ArgoCD. All deployments follow the canary release pattern with automated rollback capability.

## Prerequisites

### Infrastructure
```
□ Kubernetes cluster 1.28+
□ Helm 3.14+
□ kubectl configured with cluster context
□ ArgoCD 2.10+ installed
□ cert-manager 1.14+ installed
□ Cilium 1.15+ installed
□ Prometheus + Grafana stack installed
□ Loki + Tempo installed
□ External Secrets Operator installed
```

### Access
```
□ kubectl cluster admin access
□ ArgoCD admin credentials
□ Helm chart registry access (GHCR or ECR)
□ Docker image pull access
□ Vault authentication token for secrets
□ Slack webhook for deployment notifications
```

### Pre-Deployment Checks
```bash
# 1. Verify cluster health
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# 2. Check Helm repos are up to date
helm repo update

# 3. Verify image tags exist
docker manifest inspect ghcr.io/dgsn/backend:${VERSION}

# 4. Check that config files are valid YAML
yamllint configs/**/*.yaml

# 5. Run pre-deployment smoke tests
make pre-deploy-test

# 6. Verify secrets exist in Vault
vault list secret/dgsn/${ENVIRONMENT}/
```

## Helm Install

### Namespace Setup
```bash
# Create dgsn namespace if not exists
kubectl create namespace dgsn --dry-run=client -o yaml | kubectl apply -f -

# Label namespace for network policies
kubectl label namespace dgsn pod-security.kubernetes.io/enforce=restricted
```

### Install DGSN Stack
```bash
# Add DGSN Helm repo
helm repo add dgsn https://charts.dgsn.example.com
helm repo update

# Install PostgreSQL (primary)
helm upgrade --install dgsn-postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  --namespace dgsn \
  --values configs/postgres/values.yaml \
  --version 14.x

# Wait for PostgreSQL
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=dgsn-postgres -n dgsn --timeout=300s

# Install Redis cluster
helm upgrade --install dgsn-redis oci://registry-1.docker.io/bitnamicharts/redis-cluster \
  --namespace dgsn \
  --values configs/redis/cluster.conf \
  --version 9.x

# Install the main DGSN application
helm upgrade --install dgsn ./helm/dgsn \
  --namespace dgsn \
  --values helm/dgsn/values.yaml \
  --values helm/dgsn/values-${ENVIRONMENT}.yaml \
  --set global.imageTag=${VERSION} \
  --set global.environment=${ENVIRONMENT} \
  --wait \
  --timeout 10m

# Install monitoring stack (if not already installed)
helm upgrade --install dgsn-monitoring ./helm/dgsn-monitoring \
  --namespace dgsn \
  --values configs/prometheus/prometheus.yml \
  --values configs/loki/loki-config.yaml \
  --values configs/tempo/tempo-config.yaml \
  --values configs/grafana/grafana.ini \
  --wait \
  --timeout 5m
```

### ArgoCD GitOps Deployment
```yaml
# Application manifest (argocd/apps/dgsn.yaml)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dgsn
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/dgsn/decentralized-ground-station-network
    targetRevision: HEAD
    path: helm/dgsn
    helm:
      valueFiles:
        - values.yaml
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: dgsn
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
```

```bash
# Apply ArgoCD application
kubectl apply -f argocd/apps/dgsn.yaml

# Sync application
argocd app sync dgsn
```

## Verify Deployment

### Health Checks
```bash
# Check all pods are running
kubectl get pods -n dgsn

# Verify services
kubectl get svc -n dgsn

# Check endpoints
kubectl get endpoints -n dgsn

# Run health check endpoints
for service in backend crypto-kernel quantum-engine signal-processing; do
  kubectl run curl-${service} --image=curlimages/curl -it --rm --restart=Never \
    -- curl -s http://${service}:8080/health || true
done
```

### Integration Tests
```bash
# Run smoke tests
make smoke-test

# Run receipt creation test
curl -X POST http://backend.dgsn.svc.cluster.local:8080/api/v1/receipts \
  -H "Content-Type: application/json" \
  -d '{"station":"gs-test","satellite":"ISS","timestamp":"2025-01-01T00:00:00Z"}'

# Run crypto verification test
dgsn-crypto-cli health --endpoint crypto-kernel:50051

# Check Prometheus targets
curl http://prometheus:9090/api/v1/targets | jq '.data.activeTargets | length'

# Verify Loki is receiving logs
logcli query '{namespace="dgsn"}' --limit=1

# Verify Tempo traces
# Create a test trace via OTEL collector
```

### Metrics Verification
```bash
# Check up metric
curl http://prometheus:9090/api/v1/query?query=up

# Check receipt creation
curl http://prometheus:9090/api/v1/query?query=rate(dgsn_receipts_created_total[5m])

# Check alert rules
curl http://prometheus:9090/api/v1/rules

# Verify no firing alerts
curl http://alertmanager:9093/api/v2/alerts | jq '. | length'
```

## Smoke Tests

### Minimal Smoke Test Suite
```bash
#!/bin/bash
set -euo pipefail

echo "=== DGSN Post-Deployment Smoke Tests ==="

# 1. Service Discovery
echo "1. Checking service discovery..."
kubectl get svc -n dgsn -o name | grep -q "backend" || exit 1

# 2. Pod Readiness
echo "2. Checking pod readiness..."
READY=$(kubectl get pods -n dgsn -o jsonpath='{.items[*].status.containerStatuses[?(@.ready==true)].ready}' | wc -w)
TOTAL=$(kubectl get pods -n dgsn -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | wc -w)
if [ "$READY" -eq "$TOTAL" ]; then
  echo "   All pods ready ($READY/$TOTAL)"
else
  echo "   WARNING: $READY/$TOTAL pods ready"
fi

# 3. API Health
echo "3. Checking API health..."
HEALTH=$(kubectl run curl-health --image=curlimages/curl --rm --restart=Never \
  -- curl -s -o /dev/null -w "%{http_code}" http://backend:8080/health)
echo "   Health endpoint: $HEALTH"

# 4. Crypto Kernel
echo "4. Checking crypto kernel..."
CRYPTO=$(kubectl run curl-crypto --image=curlimages/curl --rm --restart=Never \
  -- curl -s -o /dev/null -w "%{http_code}" http://crypto-kernel:50051/health)
echo "   Crypto health: $CRYPTO"

# 5. Prometheus Targets
echo "5. Checking Prometheus..."
PROM_TARGETS=$(curl -s http://prometheus:9090/api/v1/targets | jq '.data.activeTargets | length')
echo "   Active targets: ${PROM_TARGETS}"

# 6. Alertmanager
echo "6. Checking Alertmanager..."
ALERTS=$(curl -s http://alertmanager:9093/api/v2/alerts | jq '. | length')
echo "   Active alerts: ${ALERTS}"

echo "=== Smoke tests completed ==="
```

## Rollback Procedure

### Automated Rollback (ArgoCD)
```bash
# Rollback to previous version
argocd app rollback dgsn --sync

# Or rollback to specific revision
argocd app rollback dgsn <REVISION>

# Manual sync to previous commit
argocd app sync dgsn --revision <PREVIOUS_COMMIT>
```

### Manual Rollback (Helm)
```bash
# List release history
helm history dgsn -n dgsn

# Rollback to previous revision
helm rollback dgsn 0 -n dgsn --wait --timeout 10m

# Rollback to specific revision
helm rollback dgsn <REVISION> -n dgsn --wait --timeout 10m

# Verify rollback
kubectl get pods -n dgsn
```

### Database Rollback
```bash
# If database migration was included, rollback migration
kubectl exec deployment/dgsn-backend -n dgsn -- ./dgsn migrate rollback

# Restore database from backup if needed
# See postgresql runbook for restore procedure
```

### Rollback Checklist
```
□ Confirm rollback is necessary (symptoms continue?)
□ Notify team via Slack #dgsn-deployments
□ Execute rollback (ArgoCD or Helm)
□ Verify rollback successful (all pods running)
□ Run smoke tests
□ Check metrics return to baseline
□ Declare rollback complete
□ Create incident/ticket for root cause investigation
```

## Post-Deployment Monitoring

### First 15 Minutes
- Check all pods in Running state
- Monitor error rate trends
- Verify alert rules are loading
- Confirm all Prometheus targets are UP

### First Hour
- Monitor p99 latency trends
- Check for any increase in error budget consumption
- Verify dashboard data is updating
- Run integration test suite

### First 24 Hours
- Review logs for unexpected errors
- Monitor resource usage (CPU, memory, disk)
- Check for gradual performance degradation
- Review any alert notifications

## Environment-Specific Values

### Production
```yaml
global:
  environment: production
  replicas:
    backend: 5
    crypto: 3
    quantum: 2
    signal: 3
    frontend: 3
  resources:
    backend:
      requests: {cpu: "1", memory: "2Gi"}
      limits: {cpu: "2", memory: "4Gi"}
    crypto:
      requests: {cpu: "2", memory: "4Gi"}
      limits: {cpu: "4", memory: "8Gi"}
  monitoring:
    retention_days: 90
```

### Staging
```yaml
global:
  environment: staging
  replicas:
    backend: 2
    crypto: 1
    quantum: 1
    signal: 1
    frontend: 1
  resources:
    backend:
      requests: {cpu: "500m", memory: "1Gi"}
      limits: {cpu: "1", memory: "2Gi"}
  monitoring:
    retention_days: 7
```
