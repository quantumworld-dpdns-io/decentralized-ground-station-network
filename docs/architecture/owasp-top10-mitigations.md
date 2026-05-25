# OWASP Top 10 (2021) Mitigations

## Overview

This document describes how DGSN mitigates each category of the OWASP Top 10 (2021) web application security risks.

## A01: Broken Access Control

### Description
Failures in enforcing user permissions, allowing unauthorized access to data or functionality.

### DGSN Mitigations
- **RBAC** via Casbin/OPA: roles (Viewer, Operator, Engineer, CryptoAdmin, Admin, SecurityAuditor) enforced server-side
- **ABAC** for receipts: station operators can only access own station data
- **API Gateway validation**: JWT claims validated at gateway before routing
- **gRPC interceptors**: Service-to-service authorization at every RPC
- **Cilium NetworkPolicies**: Zero-trust network segmentation prevents lateral movement

### Specific Controls
- All API endpoints require authentication (OIDC or API key)
- Role check middleware on every protected route
- Deny-by-default: no endpoint accessible without explicit grant
- Rate limiting prevents brute-force role probing

### Test Evidence
- Robot Framework tests: `tests/robot-framework/suites/owasp-top10/A01-access-control/`
- Automated role bypass tests
- IDOR (Insecure Direct Object Reference) test cases

### Residual Risk
- Low: Complex RBAC configurations may have edge cases
- Mitigated by quarterly access reviews and automated access audit

## A02: Cryptographic Failures

### Description
Weak or broken cryptography leading to data exposure.

### DGSN Mitigations
- **PQC algorithms**: ML-KEM-768, ML-DSA-65, SLH-DSA-192s (NIST FIPS 203-205)
- **TLS 1.3 minimum**: All communications encrypted in transit
- **mTLS**: Mutual authentication for service-to-service
- **AEAD**: AES-256-GCM for symmetric encryption
- **TDE**: Transparent Data Encryption for PostgreSQL
- **Column-level encryption**: Sensitive fields encrypted with per-row keys

### Specific Controls
- Cipher suite whitelist (no weak ciphers)
- Certificate pinning for critical services
- Key rotation policies (see pqc-deployment-guide.md)
- HSM backing for private keys

### Test Evidence
- Robot Framework tests: `tests/robot-framework/suites/owasp-top10/A02-crypto-failures/`
- Weak cipher detection, certificate validation, PQC fallback tests
- Automated crypto benchmarks and validation

### Residual Risk
- Low: Side-channel attacks on PQC implementations (constant-time mitigations)
- Low: Quantum computer advances (monitored, PQC migration plan)

## A03: Injection

### Description
SQL, NoSQL, OS command, LDAP, or template injection attacks.

### DGSN Mitigations
- **Parameterized queries**: All database queries use prepared statements (Go `database/sql`, Rust `sqlx`)
- **Input validation**: Structured input schemas (Protobuf for gRPC, JSON Schema for REST)
- **No raw SQL**: ORM/query builder abstractions
- **Command injection prevention**: No shell execution from user input; `exec.Command` uses fixed arguments
- **Template escaping**: Auto-escaping in Next.js and server-side templates

### Specific Controls
- Input length limits on all fields
- Type validation (strings, numbers, enums)
- Content-type enforcement
- WAF rules for SQL injection pattern matching

### Test Evidence
- Robot Framework tests: `tests/robot-framework/suites/owasp-top10/A03-injection/`
- SQL injection, command injection, template injection, LDAP injection, XML injection tests

### Residual Risk
- Low: ORM edge cases (e.g., raw query fallback)
- Low: Complex query builders may produce unexpected SQL (mitigated by SQL review in PR)

## A04: Insecure Design

### Description
Architectural flaws in application design.

### DGSN Mitigations
- **Security architecture review**: Architecture Decision Records (ADRs) document security decisions
- **Threat modeling**: STRIDE per component (see threat-model.md)
- **Defense in depth**: Multiple security layers (WAF → Gateway → Service → Database)
- **Secure defaults**: Auth required, CORS restricted, rate limiting enabled
- **Rate limiting**: Per-IP (1000/min) and per-user (100/min) limits

### Specific Controls
- Security requirements in PR review checklist
- Architecture review for new features
- Abuse case testing (Robot Framework)
- Design review sign-off from security team

### Test Evidence
- Robot Framework tests: `tests/robot-framework/suites/owasp-top10/A04-insecure-design/`
- Rate limiting, default config, missing validation, trust boundary tests

### Residual Risk
- Medium: Design flaws may be discovered post-deployment
- Mitigated by continuous monitoring and pen testing

## A05: Security Misconfiguration

### Description
Improper configuration of security settings.

### DGSN Mitigations
- **Infrastructure as Code**: All configs in version-controlled YAML/Helm charts
- **Automated deployment**: GitOps with ArgoCD prevents drift
- **Hardened base images**: Minimal container images, no unnecessary packages
- **CIS benchmarks**: Container and Kubernetes CIS benchmark compliance
- **Directory listing disabled**: Web servers configured to prevent directory traversal

### Specific Controls
- Config validation in CI (YAML lint, Helm lint, schema validation)
- Drift detection via ArgoCD diff
- Default passwords prohibited (all secrets from Vault)
- Health/readiness endpoints separated from management

### Test Evidence
- Robot Framework tests: `tests/robot-framework/suites/owasp-top10/A05-misconfig/`
- Directory listing, stack traces, CORS misconfiguration tests
- Automated config scanning with `kube-bench`, `kube-hunter`

### Residual Risk
- Low: Manual config changes outside GitOps (emergency patches)
- Low: New services may have non-standard configs

## A06: Vulnerable and Outdated Components

### Description
Using components with known vulnerabilities.

### DGSN Mitigations
- **SBOM generation**: CycloneDX SBOM generated per build
- **Dependency scanning**: Trivy and Grype in CI pipeline
- **Automated updates**: Dependabot for GitHub, Renovate for GitLab
- **Base image scanning**: Container images scanned before deployment
- **Minimal dependencies**: Go, Rust, and Julia projects minimize external deps

### Specific Controls
- CI fails on high/critical CVEs
- Weekly dependency audit report
- Vulnerability SLA: Critical (24h), High (7d), Medium (30d)
- Software supply chain security: signed commits, signed artifacts

### Test Evidence
- `security-scan.yml` GitHub Action runs Trivy
- `sbom-generate.yml` generates and uploads SBOM
- Container scan results in GitHub Security tab

### Residual Risk
- Medium: Zero-day vulnerabilities (no patch available)
- Mitigated by WAF, network segmentation, runtime security (Tetragon)

## A07: Identification and Authentication Failures

### Description
Authentication weaknesses allowing identity compromise.

### DGSN Mitigations
- **OIDC**: Industry-standard authentication with PKCE
- **MFA**: Required for admin and sensitive operations
- **Short-lived tokens**: Access tokens (15min), refresh tokens (24h)
- **Secure session management**: HTTP-only, Secure, SameSite cookies
- **Rate limiting on auth**: 5 attempts per minute per IP

### Specific Controls
- Account lockout after 10 failed attempts
- Session invalidation on logout
- Concurrent session limits
- Credential rotation policies
- Audit logging of all auth events

### Test Evidence
- Robot Framework tests for auth bypass
- Automated session management tests
- Token validation and expiry tests

### Residual Risk
- Low: Phishing (mitigated by MFA, security awareness training)
- Low: OIDC provider compromise (mitigated by redundancy)

## A08: Software and Data Integrity Failures

### Description
Compromised software or data without detection.

### DGSN Mitigations
- **Signed artifacts**: All Docker images signed with cosign
- **Supply chain SLSA Level 2**: Build provenance, signed attestations
- **Git commit signing**: Required for maintainers (GPG/Sigstore)
- **Integrity verification**: Hash verification for all dependencies
- **Checksums**: Receipt chain hash verification

### Specific Controls
- `cosign verify` in deployment pipeline
- Git tag signing for releases
- SBOM verification at deploy time
- Immutable receipt chain (blockchain-like hash linking)

### Test Evidence
- Signature verification tests in CI
- Receipt chain integrity tests
- Supply chain verification in deployment

### Residual Risk
- Low: Compromised CI/CD pipeline (mitigated by least-privilege tokens, audit)
- Low: Dependency confusion attacks (mitigated by version pinning, private registries)

## A09: Security Logging and Monitoring Failures

### Description
Insufficient logging and monitoring to detect breaches.

### DGSN Mitigations
- **Structured logging**: JSON-format logs with consistent fields
- **Centralized logging**: Loki for log aggregation and querying
- **Distributed tracing**: Tempo + OpenTelemetry for request tracing
- **Security monitoring**: Prometheus alert rules for security events
- **Audit logging**: All security-relevant events logged immutably

### Specific Controls
- Log retention: 90 days hot, 1 year cold
- Alert rules for: auth failures, unauthorized access, Tetragon violations
- Grafana dashboards for security events
- SIEM integration via Loki webhook

### Test Evidence
- Log generation and shipping tests
- Alert rule firing tests
- Dashboard validation tests

### Residual Risk
- Medium: Log tampering or deletion (mitigated by immutable log storage, WAL)
- Low: Log volume may delay analysis (mitigated by automated alerting)

## A10: Server-Side Request Forgery (SSRF)

### Description
Attacker inducing server to make requests to unintended locations.

### DGSN Mitigations
- **Network policies**: Default-deny egress via Cilium NetworkPolicies
- **No user-controlled URLs**: Backend uses fixed service endpoints from config
- **DNS resolution limited**: Only internal DNS (kube-dns) resolvable
- **Internal IP filtering**: Requests to 169.254.x.x, 127.0.0.1 blocked at gateway
- **gRPC only**: Internal communication uses gRPC, not HTTP redirects

### Specific Controls
- Egress firewall rules block non-essential external access
- Metadata endpoint (169.254.169.254) blocked at kernel level
- Proxy configuration prevents URL-based forwarding
- Input validation rejects URLs in request payloads

### Test Evidence
- SSRF-specific penetration tests
- Network policy enforcement tests
- Metadata endpoint access tests

### Residual Risk
- Low: DNS rebinding (mitigated by validate IP on connect)
- Low: Complex service mesh configurations (mitigated by Cilium L7 policies)

## OWASP Testing Infrastructure

DGSN runs automated OWASP testing via:
- **Robot Framework**: Custom security test suites in `tests/robot-framework/`
- **OWASP ZAP**: Integrated in CI (`owasp-scan.yml`)
- **Container scanning**: Trivy, Grype, Dockle
- **DAST**: Dynamic testing against staging environment

### CI Pipeline Integration
```
Build → SAST → SCA → Container Scan → Deploy → DAST → Security Test
  │       │       │         │                     │
  └───────┴───────┴─────────┴─────────────────────┴────────→ Gate
```

### Failure Policies
- Critical findings: Block deployment
- High findings: Block deployment (waiver available with security team approval)
- Medium findings: Warn, must be resolved within 30 days
- Low findings: Logged in issue tracker
