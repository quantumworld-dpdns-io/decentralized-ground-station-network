# DGSN Threat Model (STRIDE)

## Overview

This document presents the STRIDE threat model for each DGSN component, including data flow diagrams for critical flows and residual risk assessment.

## Data Flow Diagrams

### DFD 1: Receipt Creation Flow
```
[Satellite Signal]
     │
     v
[SDR Antenna] ──RF──> [Julia Signal Processor]
                            │
                    ADC samples via USB
                            │
                            v
                     [Signal Classifier]
                            │
                    Classified packet
                            │
                            v
                     [Go Backend API]
                            │
                    ┌───────┴───────┐
                    │               │
                    v               v
            [Crypto Kernel]   [PostgreSQL]
            (ML-DSA sign)     (Store receipt)
                    │               │
                    └───────┬───────┘
                            │
                            v
                      [Redis Cache]
```

### DFD 2: Receipt Verification Flow
```
[Client / External Auditor]
     │
     v
[Go Backend API]
     │
     ├─────────> [PostgreSQL] (Fetch receipt)
     │                    │
     │                    v
     │              [Crypto Kernel]
     │              (ML-DSA verify, ZKP verify)
     │                    │
     v                    v
[Verification Response]
```

## STRIDE Threat Table

### API Gateway
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T1 | Spoofing | Attacker impersonates gateway | mTLS upstream, OIDC validation, certificate pinning | Low (cert rotation mitigates) |
| T2 | Tampering | Request modification in transit | TLS 1.3, request signing, HMAC headers | Low |
| T3 | Repudiation | Deny sending requests | Structured audit logging, request IDs, WAF logs | Medium (log integrity) |
| T4 | Info Disclosure | Leak API structure/endpoints | Rate limiting, WAF, response sanitization | Low |
| T5 | DoS | Overwhelm gateway | Rate limiting (1000/min), connection limits, auto-scaling | Medium (cost) |
| T6 | Elevation | Exploit gateway to access internal | RBAC, network policies, mTLS required upstream | Low |

### Go Backend
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T7 | Spoofing | Impersonate backend | mTLS between services, SPIFFE identities | Low |
| T8 | Tampering | Receipt data modification | Immutable receipt chain, checksums on writes | Low |
| T9 | Repudiation | Deny receipt creation | Signed receipts (ML-DSA), audit log | Low |
| T10 | Info Disclosure | Leak receipt data | Field-level encryption, RBAC on reads | Medium |
| T11 | DoS | Backend resource exhaustion | Connection pool, rate limiter, HPA | Medium |
| T12 | Elevation | Privilege escalation via API | Casbin/OPA RBAC, input validation, parameterized queries | Low |

### Rust Crypto Kernel
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T13 | Spoofing | Impersonate crypto service | mTLS, PQC identity certificates | Low (PQC identity binding) |
| T14 | Tampering | Modify signing/verification | Immutable binary, signed deployments, seccomp | Low |
| T15 | Repudiation | Deny key operations | All operations logged with key ID and timestamp | Low |
| T16 | Info Disclosure | Leak private keys | HSM backing, key never in memory unencrypted, memory locking | Low |
| T17 | DoS | Exhaust crypto resources | Resource limits, operation timeouts, queue depth limits | Medium |
| T18 | Elevation | Exploit crypto to access keys | Seccomp, AppArmor, no-shell container, read-only root | Low |

### Python Quantum Engine
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T19 | Spoofing | Impersonate quantum service | mTLS, service account tokens | Low |
| T20 | Tampering | Modify circuit parameters | Input validation, circuit hashing | Medium |
| T21 | Repudiation | Deny circuit execution | Job audit log, circuit signatures | Low |
| T22 | Info Disclosure | Leak circuit IP | Circuit encryption, RBAC on results | Medium |
| T23 | DoS | Exhaust quantum resources | Queue limits, max circuit depth, job timeouts | Medium |
| T24 | Elevation | Escape quantum sandbox | Container sandbox, seccomp, no capabilities | Low |

### Julia Signal Processor
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T25 | Spoofing | Fake signal data | Signal authentication, station identity verification | Medium |
| T26 | Tampering | Modify signal samples | Signal hashing, SDR device binding | Medium |
| T27 | Repudiation | Deny signal processing | Sample audit trail | Low |
| T28 | Info Disclosure | Leak raw signal data | ADC data encryption, minimized retention | Medium |
| T29 | DoS | Overload signal processing | Buffer limits, sample rate limits | Medium |
| T30 | Elevation | Exploit Julia runtime | Seccomp, read-only filesystem, limited capabilities | Low |

### Frontend (Next.js)
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T31 | Spoofing | Identity theft via stolen tokens | OIDC with PKCE, short-lived tokens, refresh rotation | Low |
| T32 | Tampering | XSS/modify UI state | CSP headers, input sanitization, CSRF tokens | Low |
| T33 | Repudiation | Deny user actions | Session audit log, action audit trail | Low |
| T34 | Info Disclosure | Leak UI data/tokens | HTTPS only, secure cookies, no token in URL | Low |
| T35 | DoS | Client-side resource exhaustion | Rate limiting on API, CDN caching | Low |
| T36 | Elevation | Role bypass | Server-side RBAC enforcement, API validates roles | Low |

### Redis
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T37 | Spoofing | Connect without auth | Redis AUTH, TLS, network policy | Low |
| T38 | Tampering | Modify cached data | No tampering (cache only), read-replica for verification | Low |
| T39 | Repudiation | Deny cache operations | Redis slow log, minimal auditing | Low |
| T40 | Info Disclosure | Read cached receipts | Encryption at rest (AES-256), TTL-based expiry | Medium |
| T41 | DoS | Memory exhaustion | Maxmemory policy, eviction, memory limits | Medium |
| T42 | Elevation | Redis command injection | ACL restricted commands, rename dangerous commands | Low |

### PostgreSQL
| Threat | Category | Description | Mitigation | Residual Risk |
|--------|----------|-------------|------------|---------------|
| T43 | Spoofing | Database connection hijack | TLS + SCRAM-SHA-256, network policy | Low |
| T44 | Tampering | Modify receipt records | Immutable receipt table (trigger-enforced), WAL audit | Low |
| T45 | Repudiation | Deny data modifications | WAL archiving, audit triggers | Low |
| T46 | Info Disclosure | Data exfiltration | TDE, column-level encryption, row-level security | Medium |
| T47 | DoS | Connection exhaustion | Connection pooler, max connections limit | Medium |
| T48 | Elevation | SQL injection | Parameterized queries only, least-privilege roles | Low |

## Threat Severity Matrix

```
Critical (immediate action):
  T13, T16, T18 - Crypto key compromise
  T44 - Receipt modification (immutability violation)

High (action within 24h):
  T8, T10, T12, T22 - Data tampering/exposure
  T28 - Signal data leak
  T46 - Database exfiltration

Medium (action within 1 week):
  T5, T11, T17, T23, T29, T41, T47 - DoS scenarios
  T24, T30, T36 - Escalation scenarios

Low (monitor):
  Remaining threats covered by existing controls
```

## Mitigation Coverage by Control Type

| Control Type | Threats Mitigated | Coverage |
|-------------|------------------|----------|
| Cryptographic (mTLS, PQC) | T1, T7, T13, T19, T25, T37, T43 | 7 |
| Network Policy | T6, T12, T37, T43 | 4 |
| Access Control (RBAC) | T12, T18, T24, T30, T36 | 5 |
| Audit Logging | T3, T9, T15, T21, T27, T33, T39, T45 | 8 |
| Input Validation | T8, T20, T26, T32, T48 | 5 |
| Rate Limiting | T5, T11, T29, T35, T41 | 5 |
| Runtime Security | T14, T18, T24, T30 | 4 |
| Encryption at Rest | T16, T40, T46 | 3 |
| Redundancy/Auto-scaling | T5, T11, T17 | 3 |

## Attack Trees

### Attack Tree: Receipt Tampering
```
1. Modify receipt data in database
   1.1. Direct DB access
       1.1.1. Compromise DB credentials [Mitigation: Vault dynamic secrets, TLS]
       1.1.2. SQL injection [Mitigation: Parameterized queries, WAF]
   1.2. Modify in transit
       1.2.1. MitM between backend and DB [Mitigation: mTLS, network policy]
   1.3. Modify via API
       1.3.1. Bypass RBAC to direct update [Mitigation: Immutable receipt trigger]
       1.3.2. Exploit unvalidated endpoint [Mitigation: Input validation, audit]

2. Forge receipt signature
   2.1. Compromise signing key [Mitigation: HSM, never in memory]
   2.2. Replay old signature [Mitigation: Nonce, timestamp verification]
   2.3. ML-DSA forgery [Mitigation: NIST PQC standards, infeasible]

3. Break receipt chain
   3.1. Modify previous receipt hash [Mitigation: Chain-hash validation]
   3.2. Insert fraudulent receipt [Mitigation: Station identity verification]
```

### Attack Tree: Key Compromise
```
1. Extract private key from memory
   1.1. Core dump analysis [Mitigation: MADV_DONTDUMP, prctl(PR_SET_DUMPABLE)]
   1.2. Cold boot attack [Mitigation: HSM, memory encryption]
   1.3. Side-channel timing [Mitigation: Constant-time implementations]

2. Extract private key from storage
   2.1. Read HSM backup [Mitigation: Multi-party authorization, split knowledge]
   2.2. Access Vault secret [Mitigation: Vault policies, audit, MFA]
   2.3. Read filesystem key file [Mitigation: Tetragon file access policy, seccomp]

3. Intercept key during generation
   3.1. Low entropy attack [Mitigation: HSM TRNG, /dev/urandom]
   3.2. Compromised RNG [Mitigation: Continuous entropy monitoring]
```

## Residual Risk Summary

| Risk Area | Level | Rationale | Monitoring |
|-----------|-------|-----------|------------|
| Classical crypto break | Low | PQC hybrid mode, migration to PQC-only 2027 | NIST standardization tracking |
| Zero-day in PQC implementation | Low | Rust memory safety, extensive fuzzing, formal verification | CVE monitoring, dependency scanning |
| Social engineering | Medium | MFA, separation of duties | Phishing training, access reviews |
| Supply chain | Medium | Signed artifacts, SBOM, image scanning | Trivy/Grype in CI, SLSA levels |
| Side-channel attacks | Low | Constant-time impl, HSM | Benchmark monitoring, variance alerts |
| Physical access to station | Medium | TPM, disk encryption, tamper switches | Hardware monitoring, CCTV |
