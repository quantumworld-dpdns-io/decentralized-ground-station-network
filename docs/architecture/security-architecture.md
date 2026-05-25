# DGSN Security Architecture

## Overview

DGSN implements a defense-in-depth security architecture with post-quantum cryptography, eBPF-based runtime security, zero-trust networking, and comprehensive audit logging.

## Security Layers

```
Layer 1: Application Security
  - Post-quantum crypto (ML-KEM, ML-DSA, SLH-DSA)
  - Zero-knowledge proofs for receipt verification
  - Input validation and rate limiting

Layer 2: Service Security
  - mTLS between all gRPC services
  - OAuth 2.0 / OIDC authentication
  - Role-based access control (RBAC)

Layer 3: Runtime Security
  - Cilium Tetragon eBPF monitoring
  - Seccomp profiles for containers
  - AppArmor/SELinux policies

Layer 4: Network Security
  - Cilium NetworkPolicy (zero-trust)
  - Encrypted inter-service communication
  - API gateway with WAF

Layer 5: Infrastructure Security
  - Kubernetes RBAC + audit logging
  - Secrets management (External Secrets Operator)
  - Image scanning and signing
```

## Post-Quantum Cryptography

### Key Management

| Key Type | Algorithm | Usage | Rotation |
|----------|-----------|-------|----------|
| Identity | SLH-DSA-192s | Long-term station identity | 12 months |
| Session | ML-KEM-768 | Ephemeral session keys | Per-session |
| Receipt | ML-DSA-65 | Receipt signing | 6 months |
| Backup | ML-KEM-1024 | Data encryption at rest | 24 months |

### Key Hierarchy

```
Root CA (SLH-DSA-256f)
  ├── Station Identity Key (SLH-DSA-192s)
  │     ├── Session Key (ML-KEM-768)
  │     └── Receipt Signing Key (ML-DSA-65)
  └── Operator Key (ML-DSA-87)
        └── API Token Key (ML-DSA-44)
```

## Runtime Security (eBPF)

### Tetragon Tracing Policies

See `configs/cilium/tetragon-tracing-policy.yaml`:
- Signal processing process monitoring
- USB/SDR device access tracking
- Network connection auditing
- File system access control

### Tetragon Security Policies

See `configs/cilium/tetragon-security-policy.yaml`:
- Unauthorized process execution prevention
- Sensitive file access monitoring
- Privilege escalation detection
- Container breakout prevention

## Network Security

### Zero-Trust Network Policies

See `configs/cilium/network-policy.yaml`:
- Default deny ingress/egress
- Service-to-service allowlists
- DNS-external access denied by default
- Allowed ports strictly defined

### Service Mesh (Future)

- Istio or Cilium Service Mesh for mTLS
- Layer 7 policies for HTTP/gRPC
- Circuit breaking and retry budgets

## Secrets Management

External Secrets Operator integrates with:
- AWS Secrets Manager (production)
- GCP Secret Manager (disaster recovery)
- Azure Key Vault (optional)

### Secret Types

| Secret | Storage | Rotation |
|--------|---------|----------|
| DB password | AWS Secrets Manager | 90 days |
| Redis password | AWS Secrets Manager | 90 days |
| API keys | AWS Secrets Manager | Manual |
| TLS certs | cert-manager + Let's Encrypt | 90 days |
| PQC private keys | Vault + HSM | Policy-based |

## Audit Logging

### Kubernetes Audit Policy

See `configs/cilium/audit-policy.yaml`:
- All pod exec and secret access logged at RequestResponse level
- All changes to RBAC and NetworkPolicy logged
- Failed authentication attempts detailed
- Health checks excluded from audit log

### OpenTelemetry Tracing

All inter-service calls traced with OpenTelemetry:
- Span attributes include security context
- Trace sampling prioritizes error spans
- Exemplars link metrics to traces

## Incident Response

See `docs/runbooks/incident-response.md` for detailed procedures.

## Compliance

See the following documents:
- `docs/architecture/compliance-soc2.md` - SOC 2 compliance mapping
- `docs/architecture/threat-model.md` - STRIDE threat model
- `docs/architecture/pqc-deployment-guide.md` - PQC deployment guide

## Security Monitoring

### Prometheus Alerts
- `configs/prometheus/alert-rules.yml` - Real-time security alerts
- Dashboard: `configs/grafana/dashboards/security-events.json`

### Key Metrics
- `dgsn_security_alerts_total{severity}` - Security alerts by severity
- `dgsn_tetragon_signal_violations_total` - eBPF policy violations
- `dgsn_auth_failures_total` - Authentication failures
- `dgsn_zkp_verification_failures_total` - ZKP verification failures
- `dgsn_unauthorized_access_total` - Unauthorized access attempts

## Disaster Recovery

1. **Key Material**: HSM-backed backup in multiple regions
2. **Secrets**: Replicated across secret stores
3. **Config**: GitOps with ArgoCD, all configs in version control
4. **Data**: PostgreSQL WAL streaming + S3 backups
