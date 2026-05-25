# Horizontal Scaling Guide

## Overview

This guide covers horizontal scaling strategies for all DGSN components, including HPA configuration, cluster scaling, data partition scaling, and quantum backend scaling.

## HPA Configuration

### Backend API
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dgsn-backend
  namespace: dgsn
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dgsn-backend
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    - type: Pods
      pods:
        metric:
          name: dgsn_api_requests_per_second
        target:
          type: AverageValue
          averageValue: 500
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
        - type: Pods
          value: 4
          periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 25
          periodSeconds: 120
```

### Crypto Kernel
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dgsn-crypto-kernel
  namespace: dgsn
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dgsn-crypto-kernel
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Pods
      pods:
        metric:
          name: dgsn_crypto_operations_per_second
        target:
          type: AverageValue
          averageValue: 1000
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Pods
          value: 2
          periodSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 180
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
```

### Quantum Engine
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dgsn-quantum-engine
  namespace: dgsn
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dgsn-quantum-engine
  minReplicas: 1
  maxReplicas: 8
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
    - type: Pods
      pods:
        metric:
          name: dgsn_quantum_active_circuits
        target:
          type: AverageValue
          averageValue: 5
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 33
          periodSeconds: 120
```

### Signal Processing
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dgsn-signal-processing
  namespace: dgsn
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dgsn-signal-processing
  minReplicas: 2
  maxReplicas: 15
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
    - type: Pods
      pods:
        metric:
          name: dgsn_signal_queue_depth
        target:
          type: AverageValue
          averageValue: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Pods
          value: 2
          periodSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 180
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
```

### Frontend
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dgsn-frontend
  namespace: dgsn
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dgsn-frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 25
          periodSeconds: 120
```

## Cluster Scaling

### Cluster Autoscaler
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-config
  namespace: kube-system
data:
  config: |
    max-nodes-total: 50
    min-nodes-total: 3
    scale-down-delay-after-add: 10m
    scale-down-delay-after-delete: 10m
    scale-down-delay-after-failure: 10m
    scale-down-unneeded-time: 10m
    scale-down-utilization-threshold: 0.5
    max-node-provision-time: 15m
    balancing-similar-node-groups: true
    scale-down-enabled: true
```

### Node Group Configuration
| Node Group | Instance Type | Min | Max | Use Case |
|-----------|--------------|-----|-----|----------|
| general | t3.large | 2 | 20 | Backend, frontend, monitoring |
| compute | c6i.2xlarge | 1 | 10 | Crypto kernel, quantum engine |
| memory | r6i.2xlarge | 1 | 5 | PostgreSQL, Redis |
| gpu | p3.2xlarge | 0 | 4 | Quantum simulation (GPU) |

### Taints and Tolerations
```yaml
# GPU nodes
spec:
  taints:
    - key: nvidia.com/gpu
      value: "true"
      effect: NoSchedule

# High-memory nodes  
spec:
  taints:
    - key: dedicated
      value: dgsn-db
      effect: NoSchedule
```

## Data Partition Scaling

### PostgreSQL
```bash
# Vertical scaling
# Increase instance size via RDS or StatefulSet resource update
kubectl set resources statefulset/dgsn-postgres \
  -n dgsn \
  --requests=cpu=4,memory=16Gi \
  --limits=cpu=8,memory=32Gi

# Read replicas
kubectl scale statefulset/dgsn-postgres-read -n dgsn --replicas=3
```

### Redis Cluster
```bash
# Scale Redis cluster (6 nodes minimum for 3 shards)
redis-cli --cluster add-node new-node:6379 existing-node:6379
redis-cli --cluster reshard existing-node:6379 --cluster-from all --cluster-to <node-id> --cluster-slots 1000

# Or via Helm
helm upgrade dgsn-redis oci://registry-1.docker.io/bitnamicharts/redis-cluster \
  --set cluster.nodes=6
```

### Loki
```yaml
# Scale Loki ingesters
ingester:
  replicas: 5
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetMemoryUtilizationPercentage: 75
```

### Tempo
```yaml
# Scale Tempo ingesters
ingester:
  replicas: 3
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 8
    targetMemoryUtilizationPercentage: 75
```

## Quantum Backend Scaling

### Simulator Scaling
```yaml
# Python quantum engine - simulator
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dgsn-quantum-simulator
spec:
  scaleTargetRef:
    kind: Deployment
    name: dgsn-quantum-simulator
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Pods
      pods:
        metric:
          name: dgsn_quantum_simulator_queue_depth
        target:
          type: AverageValue
          averageValue: 3
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
```

### Hardware Backend (Cloud Quantum)
```yaml
# Quantum cloud connection pooling
apiVersion: v1
kind: ConfigMap
metadata:
  name: quantum-hardware-config
data:
  max_concurrent_jobs: "5"
  provider_quota_monitoring: "true"
  fallback_on_quota_exceeded: "true"
  auto_queue_enabled: "true"
```

### GPU-Accelerated Simulation
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dgsn-quantum-gpu
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: quantum-gpu
          resources:
            limits:
              nvidia.com/gpu: 1
      nodeSelector:
        nvidia.com/gpu: "true"
```

## Metrics-Based Triggers

### Custom Metrics API
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dgsn-backend-custom
spec:
  metrics:
    - type: Object
      object:
        metric:
          name: dgsn_api_queue_depth
        describedObject:
          apiVersion: v1
          kind: Service
          name: dgsn-backend
        target:
          type: Value
          value: 100
    - type: External
      external:
        metric:
          name: dgsn_prometheus_errors_total
          selector:
            matchLabels:
              service: dgsn-backend
        target:
          type: AverageValue
          averageValue: 10
```

### ScaledObject (KEDA)
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: dgsn-backend-keda
  namespace: dgsn
spec:
  scaleTargetRef:
    name: dgsn-backend
  minReplicaCount: 3
  maxReplicaCount: 20
  triggers:
    - type: prometheus
      metricType: AverageValue
      metadata:
        serverAddress: http://prometheus:9090
        metricName: dgsn_api_requests_per_second
        query: sum(rate(dgsn_api_requests_total[2m]))
        threshold: "500"
    - type: prometheus
      metricType: Utilization
      metadata:
        serverAddress: http://prometheus:9090
        metricName: dgsn_api_error_rate_5m
        query: sum(rate(dgsn_api_requests_total{status=~"5.."}[5m])) / sum(rate(dgsn_api_requests_total[5m]))
        threshold: "0.05"
```

## Cooldown Periods

| Service | Scale Up Cooldown | Scale Down Cooldown | Rationale |
|---------|------------------|---------------------|-----------|
| Backend API | 60s | 300s | Quick scale up for traffic spikes; slow scale down to handle lingering requests |
| Crypto Kernel | 30s | 180s | Fast scale up for signing bursts; moderate scale down |
| Quantum Engine | 60s | 300s | Circuits are long-running; avoid thrashing |
| Signal Processing | 30s | 180s | Fast scale up for satellite passes; moderate scale down |
| Frontend | 60s | 300s | Web traffic can spike; avoid pod churn |
| Database | Manual | Manual | Stateful scaling requires careful planning |
| Redis | Manual | Manual | Cluster resharding is complex |

## Scaling Limits

### Per-Service Limits
| Service | Min Replicas | Max Replicas | Scale Up Rate | Scale Down Rate |
|---------|-------------|-------------|---------------|-----------------|
| Backend | 3 | 20 | 4 pods/60s | 25%/120s |
| Crypto | 2 | 10 | 2 pods/30s | 50%/60s |
| Quantum | 1 | 8 | 1 pod/60s | 33%/120s |
| Signal | 2 | 15 | 2 pods/30s | 50%/60s |
| Frontend | 2 | 10 | 100%/60s | 25%/120s |

### Cluster-Wide Limits
- Max pods per node: 110 (EKS/GKE default)
- Max nodes: 50 (cluster autoscaler config)
- Max concurrent scaling operations: 5
- Scale-up budget: 50% of current replicas per 10 minutes
- Scale-down budget: 25% of current replicas per 10 minutes

## Monitoring Scaling

### Prometheus Recording Rules
```prometheus
# HPA metrics
- record: dgsn:hpa_replicas_current
  expr: kube_horizontalpodautoscaler_spec_target_replicas

- record: dgsn:hpa_replicas_desired
  expr: kube_horizontalpodautoscaler_status_desired_replicas

# Scaling events
- record: dgsn:scale_up_events_total
  expr: increase(kube_horizontalpodautoscaler_status_desired_replicas[5m]) > 0

- record: dgsn:scale_down_events_total
  expr: -increase(kube_horizontalpodautoscaler_status_desired_replicas[5m]) > 0
```

### Alerts
```prometheus
- alert: DGSN_MaxReplicasReached
  expr: kube_horizontalpodautoscaler_status_desired_replicas == kube_horizontalpodautoscaler_spec_max_replicas
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "HPA {{ $labels.horizontalpodautoscaler }} at max replicas"
    description: "{{ $labels.horizontalpodautoscaler }} has reached its maximum replica count."

- alert: DGSN_ScaleUpOscillation
  expr: |
    changes(kube_horizontalpodautoscaler_status_desired_replicas[15m]) > 6
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "HPA oscillating"
    description: "{{ $labels.horizontalpodautoscaler }} has changed desired replicas >6 times in 15 minutes."
```

### Dashboard Panels
- Current vs desired replicas per service
- Scale-up/scale-down event timeline
- Resource utilization heatmap
- Pending pods count
- Cluster node utilization
