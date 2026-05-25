# Zero-Trust Architecture

## Overview

DGSN implements a zero-trust architecture (ZTA) following NIST SP 800-207 guidelines. The architecture assumes no implicit trust based on network location and requires continuous verification of every access request.

## Core Principles

### 1. Network Segmentation
DGSN uses Cilium NetworkPolicies to create micro-perimeters around each service:

```
┌─────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                    │
│                                                          │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐              │
│  │ Frontend │    │ Backend │    │  Redis  │              │
│  │  (DMZ)   │───▶│ (App)   │───▶│ (Cache) │              │
│  └─────────┘    └─────────┘    └─────────┘              │
│                      │    │                              │
│                      ▼    ▼                              │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐              │
│  │  Crypto │    │ Quantum │    │ Signal  │              │
│  │ (Kernel)│    │ (Engine)│    │ (Proc)  │              │
│  └─────────┘    └─────────┘    └─────────┘              │
│                                                          │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐              │
│  │  Tempo  │    │  Loki   │    │ Prometheus│             │
│  │(Traces) │    │ (Logs)  │    │(Metrics)│              │
│  └─────────┘    └─────────┘    └─────────┘              │
└─────────────────────────────────────────────────────────┘
```

### 2. Identity-Based Access
- **Service identities**: SPIFFE/SPIRE X.509 SVIDs for each workload
- **Human identities**: OIDC claims from corporate IdP
- **Device identities**: TPM-backed attestation for ground stations

### 3. Continuous Verification
- Every request authenticated and authorized regardless of network path
- mTLS with short-lived certificates (24h)
- Token introspection on every API call
- eBPF-based runtime verification of process behavior

### 4. Least Privilege
- Default-deny network policy
- RBAC roles with minimum necessary permissions
- Just-in-time (JIT) access for admin operations
- Ephemeral credentials (Vault dynamic secrets)

### 5. Micro-Perimeter
Each service has its own security boundary:

| Service | Ingress Allowed From | Port(s) | Egress Allowed To | Notes |
|---------|---------------------|---------|-------------------|-------|
| Frontend | Ingress Gateway | 3000 | Backend:8080, DNS:53 | No egress to internet |
| Backend | Frontend | 8080 | All services, DB:5432, Redis:6379 | Monitor access |
| Crypto | Backend only | 50051 | OTEL:4317, DNS:53 | No other egress |
| Quantum | Backend only | 50052 | OTEL:4317, Redis:6379, DNS:53 | |
| Signal | Backend only | 50053 | OTEL:4317, DNS:53 | SDR via USB only |
| Redis | Backend, Quantum | 6379 | None (data only) | No network egress |
| PostgreSQL | Backend only | 5432 | None | No network egress |

### 6. Device Trust
- Ground stations registered with hardware-backed identity (TPM 2.0)
- Station attestation before processing allocation
- Runtime integrity monitoring via Tetragon
- Remote attestation for software measurement

### 7. Data Protection
- All data encrypted at rest (TDE + AEAD)
- All data encrypted in transit (TLS 1.3 + mTLS)
- Field-level encryption for PII
- Data classification labels on receipts

### 8. Automation and Orchestration
- GitOps with ArgoCD for policy-as-code
- Policy changes require PR + approval
- Automated policy testing in CI/CD
- Drift detection via continuous reconciliation

## Implementation Details

### Cilium NetworkPolicies
See `configs/cilium/network-policy.yaml` for full policy definitions.

Key policies:
- **Default deny**: All ingress/egress denied unless explicitly allowed
- **Service allowlists**: Label-based policies for each service pair
- **DNS allowlist**: Only internal DNS (kube-dns) accessible
- **NTP allowlist**: NTP egress for time synchronization

### mTLS Configuration
```yaml
# Cilium mTLS between services
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
spec:
  endpointSelector:
    matchLabels:
      app: dgsn-backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: dgsn-frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
        # L7 policy for HTTP
        rules:
          http:
            - method: GET
              path: "/api/v1/receipts/*"
```

### Identity Federation
```
Human User → OIDC Provider → JWT → API Gateway → Backend
                                                        │
Service ← SPIFFE SVID ← SPIRE Agent ← SPIRE Server ────┘
Station ← TPM Attestation ← Station Service ← Backend
```

### Continuous Verification Points
1. **Network layer**: Cilium verifies identity for every packet
2. **Transport layer**: mTLS handshake verifies service identity
3. **Application layer**: JWT/OIDC validation on every API call
4. **Runtime layer**: Tetragon traces verify process behavior
5. **Data layer**: Encryption ensures data integrity

## Trust Boundaries

### Trust Zones
```
[Internet] ──WAF──> [DMZ Zone] ──mTLS──> [App Zone] ──mTLS──> [Data Zone]
                       │                    │                    │
                  Frontend            Backend, Crypto,       PostgreSQL,
                                      Quantum, Signal        Redis
```

### Policy Enforcement Points (PEPs)
| Location | PEP Type | Enforcement |
|----------|----------|-------------|
| API Gateway | L7 Proxy | AuthN, AuthZ, Rate limit, WAF |
| Service mesh sidecar | L4+L7 | mTLS, L7 policy |
| Cilium eBPF | L3+L4 | Network policy, identity |
| Tetragon | Kernel | Syscall monitoring, process control |

### Policy Decision Points (PDPs)
| Location | PDP Type | Decisions |
|----------|----------|-----------|
| OIDC Provider | External | Authentication |
| OPA/Casbin | Service-side | Authorization |
| Cilium Agent | Node-local | Network policy decision |
| SPIFFE/SPIRE | Cluster-wide | Workload identity |

## Monitoring Zero-Trust

### Key Metrics
```prometheus
# AuthN/AuthZ
dgsn_auth_failures_total{reason="invalid_token"}
dgsn_auth_failures_total{reason="expired"}
dgsn_unauthorized_access_total

# Network policy
dgsn_network_policy_denies_total
dgsn_network_connections_blocked_total

# mTLS
dgsn_mtls_handshake_failures_total
dgsn_certificate_expiry_days

# Runtime
dgsn_tetragon_violations_total
dgsn_tetragon_process_blocked_total
```

### Dashboards
- `configs/grafana/dashboards/security-events.json` - Security event monitoring
- Network policy violations, auth failures, mTLS status

### Alerts
- `DGSN_UnauthorizedAccessSpike` - >10 unauthorized attempts/s
- `DGSN_TetragonViolation` - >5 eBPF policy violations/s
- `DGSN_CertificateExpiringSoon` - <30 days to expiry

## Benefits

| Benefit | Description | Measurement |
|---------|-------------|-------------|
| Reduced blast radius | Compromised pod cannot access other services | Number of accessible services from each pod: 1-3 |
| Breach detection | Multiple verification layers detect anomalies | Time to detect: < 1 minute |
| Compliance | SOC 2, ISO 27001 alignment | Audit mapping in compliance-soc2.md |
| Defense in depth | No single point of trust failure | Layers: 6 (network, transport, app, runtime, data, identity) |

## Incident Scenarios

### Scenario 1: Compromised Backend Pod
1. Attacker exploits vulnerability in backend
2. Cilium NetworkPolicy prevents egress to internet
3. Tetragon detects unexpected process execution
4. Alert fires within seconds
5. Pod automatically terminated by security policy

### Scenario 2: Stolen API Key
1. API key leaked to unauthorized party
2. OIDC JWT valid, but source IP outside allowed range
3. Rate limit exceeded due to automated scanning
4. Account locked after failed access attempts
5. Incident alert generated for security team

### Scenario 3: Malicious Insider
1. Operator account compromised
2. Accesses receipts outside assigned station (ABAC violation)
3. Audit log captures unauthorized read
4. Security team notified within minutes
5. Access revoked, investigation initiated
