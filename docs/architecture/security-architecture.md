# DGSN Security Architecture

## Overview

DGSN implements a defense-in-depth security architecture with post-quantum cryptography (PQC), eBPF-based runtime security with Cilium Tetragon, zero-trust networking via Cilium NetworkPolicies, and comprehensive audit logging. This document covers the full security posture including threat model, encryption, authentication, authorization, secrets management, and compliance.

## Threat Model (STRIDE Per Component)

| Component | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | Elevation of Privilege |
|-----------|----------|-----------|-------------|-----------------|-----|----------------------|
| API Gateway | OIDC + mTLS | Request signing | Audit logging | TLS 1.3 | Rate limiting | RBAC + OPA |
| Go Backend | mTLS | Receipt hashing | Audit trail | Field-level encrypt | Connection pool | RBAC |
| Rust Crypto Kernel | PQC identity | ML-DSA signing | Non-repudiation | ML-KEM encrypt | Resource limits | Seccomp |
| Python Quantum | mTLS | Input validation | Job audit | Circuit encryption | Queue limits | RBAC |
| Julia Signal | mTLS | Signal hashing | Sample audit | ADC encryption | Buffer limits | Seccomp |
| Frontend | OIDC login | CSRF tokens | Session audit | HTTPS only | Rate limiting | RBAC |
| Redis | AUTH + TLS | No tampering | Logging | Encrypted at rest | Memory limits | ACL |
| PostgreSQL | TLS + SCRAM | FK constraints | WAL audit | TDE + AEAD | Connection pool | Row-level security |

## Encryption

### At Rest
- **PostgreSQL**: Transparent Data Encryption (TDE) + column-level AEAD for PII
- **Redis**: Encrypted at rest via Redis Enterprise or AESCrypt
- **S3/MinIO**: Server-side encryption with ML-KEM-1024 wrapped keys
- **Key Material**: Stored in Vault with HSM backing, encrypted with ML-KEM-1024
- **Receipt Store**: Individual receipt encryption using ML-KEM-768 per-receipt keys

### In Transit
- **mTLS**: All gRPC services use mutual TLS with X.509 certs
- **TLS 1.3**: Minimum TLS version across all HTTP/gRPC endpoints
- **PQC Hybrid**: X25519 + ML-KEM-768 key exchange, Ed25519 + ML-DSA-65 signatures
- **Cipher Suites**:
  - TLS_AES_256_GCM_SHA384
  - TLS_CHACHA20_POLY1305_SHA256
  - TLS_ECDHE_KYBER_MLKEM768_WITH_AES_256_GCM_SHA384 (PQC hybrid)

## Authentication

### OIDC (Primary)
- Provider: Dex, Keycloak, or cloud IdP (Okta, Azure AD)
- Flows: Authorization Code + PKCE for web; Client Credentials for services
- Token types: JWT access tokens (15min), refresh tokens (24h), ID tokens
- MFA enforced for all human users via OIDC provider
- Service accounts use SPIFFE/SPIRE identities for workload auth

### API Keys (Secondary)
- For machine-to-machine communication when OIDC is impractical
- Scoped to specific service + action
- Rotated every 90 days via Vault
- Stored as bcrypt hashes in PostgreSQL

### MFA
- Required for: admin access, key rotation, configuration changes
- Supported: TOTP (RFC 6238), WebAuthn/FIDO2, hardware security keys
- Enforced at OIDC provider level

## Authorization (RBAC)

| Role | Permissions | Scope |
|------|------------|-------|
| Viewer | Read dashboards, view receipts | Read-only |
| Operator | Create/view receipts, manage stations | Station operations |
| Engineer | Deploy circuits, manage quantum jobs | Quantum + signal |
| CryptoAdmin | Rotate PQC keys, manage certificates | Crypto kernel |
| Admin | Full access, RBAC management, audit | Everything |
| SecurityAuditor | Read audit logs, compliance reports | Read-only audit |

RBAC enforced via:
- Kubernetes RBAC for infrastructure
- Application-level RBAC in Go backend (Casbin or OPA)
- gRPC interceptor for service-to-service authorization
- Attribute-based access control (ABAC) for receipts (station ownership)

## PQC Integration

DGSN integrates three NIST-standardized post-quantum algorithms:

- **ML-KEM (FIPS 203)**: Key encapsulation for session establishment
- **ML-DSA (FIPS 204)**: Digital signatures for receipt verification
- **SLH-DSA (FIPS 205)**: Stateless hash-based signatures for long-term identity

See `docs/architecture/pqc-deployment-guide.md` for detailed deployment procedures.

## Zero-Trust Networking

DGSN implements a zero-trust architecture using Cilium NetworkPolicies:

1. **Default Deny**: All ingress/egress denied by default
2. **Micro-segmentation**: Each service has its own policy
3. **Identity-based**: Policies use Kubernetes labels, not IPs
4. **L7 aware**: HTTP/gRPC methods enforced via Cilium L7 policies
5. **Continuous verification**: eBPF monitors all connections

See `docs/architecture/zero-trust.md` for detailed architecture.

## Secrets Management

### Vault Integration
- HashiCorp Vault for all secrets storage
- HSM backing for PQC private keys
- Dynamic secrets for databases (short-lived credentials)
- Automatic rotation every 90 days

### Secret Types
| Secret | Storage | Rotation | Access |
|--------|---------|----------|--------|
| Database credentials | Vault dynamic secrets | 24h | Backend only |
| Redis password | Vault static | 90 days | Services |
| PQC private keys | Vault + HSM | Policy-based | CryptoAdmin |
| TLS certificates | cert-manager | 90 days | All services |
| API keys | Vault | 90 days | Per service |
| OIDC client secrets | Vault | Manual | Auth service |

### External Secrets Operator
- Syncs Vault secrets to Kubernetes Secrets
- Mutating webhook injects secrets into pods
- Audit-logged via Kubernetes audit policy

## Audit Logging

### Kubernetes Audit
- All pod exec, secret access, RBAC changes logged
- Metadata level: RequestResponse for sensitive operations
- Logs shipped to Loki for querying

### Application Audit
- Every receipt creation/verification logged
- All auth attempts (success/failure) logged
- PQC key operations logged
- Configuration changes logged
- Audit events include: timestamp, actor, action, resource, result

### Retention
- Application audit logs: 90 days hot (Loki), 1 year cold (S3)
- Kubernetes audit logs: 30 days hot, 1 year cold
- Receipt chain: Permanent (immutable ledger)

## Incident Response

See `docs/runbooks/incident-response.md` for detailed procedures covering:
- Security Breach
- Service Outage
- Data Loss
- Quantum Circuit Failure
- PQC Key Compromise
- DDoS Attack

## Compliance

### SOC 2
- Security: CC1-CC9 controls mapped
- Availability: Uptime monitoring, redundancy
- Processing Integrity: Receipt verification chain
- Confidentiality: Encryption at rest/in transit
- Privacy: PII minimization, retention limits

See `docs/architecture/compliance-soc2.md` for full mapping.

### ISO 27001
- A.5 Information security policies
- A.6 Organization of information security
- A.8 Asset management
- A.9 Access control
- A.10 Cryptography
- A.12 Operations security
- A.16 Incident management
- A.18 Compliance

### NIST CSF
- Identify: Asset management, risk assessment
- Protect: Access control, data security, maintenance
- Detect: Continuous monitoring, anomaly detection
- Respond: Incident response, analysis
- Recover: Recovery planning, improvements

## Security Monitoring

### Prometheus Alerts
- Real-time security alerts in `configs/prometheus/alert-rules.yml`
- Covers: high error rates, auth failures, certificate expiry, disk space

### Grafana Dashboards
- `configs/grafana/dashboards/security-events.json` - Security event monitoring
- PQC algorithm usage, audit log counts, failed auth attempts

### eBPF Monitoring (Tetragon)
- Process execution monitoring
- File system access control
- Network connection auditing
- Capability usage detection

## Network Security

### Firewall Rules
| Direction | Source | Destination | Port | Protocol | Purpose |
|-----------|--------|-------------|------|----------|---------|
| Ingress | Internet | API Gateway | 443 | TCP | External API |
| Ingress | Frontend | Backend | 8080 | TCP | API calls |
| Ingress | Backend | Crypto | 50051 | TCP | gRPC crypto |
| Ingress | Backend | Quantum | 50052 | TCP | gRPC quantum |
| Ingress | Backend | Signal | 50053 | TCP | gRPC signal |
| Ingress | OTEL | Prometheus | 9090 | TCP | Metrics scrape |
| Egress | All | DNS | 53 | UDP | DNS resolution |
| Egress | All | NTP | 123 | UDP | Time sync |

### WAF Rules (Apache/CloudFront)
- SQL injection detection blocked at gateway
- XSS payload filtering
- Rate limiting: 1000 req/min per IP
- Request size limit: 10MB
- Blocked countries configurable

## Disaster Recovery

### RTO/RPO
- Receipt processing: RTO 5min, RPO 1min
- API service: RTO 2min, RPO 0 (stateless)
- Quantum jobs: RTO 30min, RPO (restart from checkpoint)
- Crypto keys: RTO 15min, RPO 0 (HSM replicated)

### Backup Strategy
- PostgreSQL: WAL streaming + daily snapshots (30d retention)
- Redis: AOF + RDB snapshots (7d retention)
- Receipts: Dual-write to S3 + PostgreSQL (permanent)
- Config: GitOps with ArgoCD (infinite retention)
- Keys: HSM backup in secondary region

## Security Controls Summary

| Control | Implementation | Verification |
|---------|---------------|-------------|
| Access control | OIDC + RBAC + ABAC | Quarterly access review |
| Encryption at rest | TDE + AEAD | Automated key rotation test |
| Encryption in transit | TLS 1.3 + mTLS | Continuous cipher suite monitoring |
| Input validation | Gateway + service-level | DAST scan monthly |
| Audit logging | Structured + immutable | Weekly log review |
| Vulnerability mgmt | Trivy + Grype scans | CI pipeline blocking |
| Incident response | Documented runbooks | Tabletop exercises quarterly |
| Business continuity | Multi-AZ + DR region | Annual DR test |
| Supplier security | SBOM + sig verification | Pre-deployment scan |
