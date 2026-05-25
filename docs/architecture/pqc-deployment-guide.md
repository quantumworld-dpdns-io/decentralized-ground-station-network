# Post-Quantum Cryptography Deployment Guide

## Overview

This guide covers deployment, operation, and migration of post-quantum cryptography (PQC) in DGSN. DGSN implements the three NIST-standardized post-quantum algorithms (FIPS 203, 204, 205) in a phased approach, starting with hybrid mode and progressing to PQC-only where possible.

## Algorithm Selection

### FIPS 203: ML-KEM (Module-Lattice Key Encapsulation Mechanism)
| Variant | Security Level | Public Key | Secret Key | Ciphertext | Use Case |
|---------|---------------|------------|------------|------------|----------|
| ML-KEM-512 | NIST Level 1 (128-bit) | 800 B | 1,632 B | 768 B | Low-security sessions |
| ML-KEM-768 | NIST Level 3 (192-bit) | 1,184 B | 2,400 B | 1,089 B | Default session establishment |
| ML-KEM-1024 | NIST Level 5 (256-bit) | 1,568 B | 3,168 B | 1,568 B | Data at rest encryption |

### FIPS 204: ML-DSA (Module-Lattice Digital Signature Algorithm)
| Variant | Security Level | Public Key | Secret Key | Signature | Use Case |
|---------|---------------|------------|------------|-----------|----------|
| ML-DSA-44 | NIST Level 1 | 1,312 B | 2,560 B | 2,420 B | ZKP circuits, high-throughput |
| ML-DSA-65 | NIST Level 3 | 1,952 B | 4,000 B | 3,309 B | Default receipt signing |
| ML-DSA-87 | NIST Level 5 | 2,592 B | 4,864 B | 4,627 B | Operator keys, governance |

### FIPS 205: SLH-DSA (Stateless Hash-Based Digital Signature)
| Variant | Security Level | Public Key | Secret Key | Signature | Use Case |
|---------|---------------|------------|------------|-----------|----------|
| SLH-DSA-128f | NIST Level 1 (fast) | 32 B | 64 B | 17,088 B | Fast verification |
| SLH-DSA-192s | NIST Level 3 (small) | 48 B | 96 B | 35,664 B | Station identity (default) |
| SLH-DSA-256f | NIST Level 5 (fast) | 64 B | 128 B | 49,856 B | Audit trail, root CA |

## Algorithm Selection Guide

| Use Case | Primary Algorithm | Fallback | Rationale |
|----------|------------------|----------|-----------|
| Receipt signing | ML-DSA-65 | Ed25519 | Balance of signature size and security |
| Station identity | SLH-DSA-192s | Ed25519 | Stateless, long-term (12 months) |
| Session establishment | ML-KEM-768 | X25519 | NIST standard, efficient key exchange |
| Data at rest | ML-KEM-1024 + AES-256-GCM | RSA-4096 | Hybrid encryption for stored data |
| ZKP circuits | ML-DSA-44 | Ed25519 | Faster proving, smaller signatures |
| Audit trail | SLH-DSA-256f | ML-DSA-87 | Maximum long-term security (50+ years) |
| TLS handshake | X25519 + ML-KEM-768 | ECDHE + ML-KEM | Hybrid for broad compatibility |

## Hybrid Mode vs PQC-Only

### Phase 1: Hybrid Mode (Current Deployment)
- TLS 1.3 with X25519 + ML-KEM-768 hybrid key exchange
- Dual signatures: Ed25519 + ML-DSA-65
- Certificate chains use classical intermediates + PQC end-entity
- Provides forward compatibility and classical security simultaneously

### Phase 2: PQC-Only (Target: Q4 2026)
- TLS 1.3 exclusively with ML-KEM-768
- ML-DSA-65 for all digital signatures
- SLH-DSA-192s for long-term identity and root CA
- Requires: OQS provider support in all clients, NIST CNSA 2.0 compliance

### Migration Path
```
Classical ──> Hybrid ──> PQC Preferred ──> PQC Only
  2024        2025          2026               2027
```

## TLS Configuration

### OpenSSL / BoringSSL (Go Backend)
```
ssl_ciphers = TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
ssl_curves = X25519:MLKEM768:secp384r1:secp256r1
ssl_sigalgs = MLDSA65:Ed25519:ecdsa_secp384r1_sha384:rsa_pss_rsae_sha256
ssl_min_version = TLSv1.3
```

### Rust Crypto Kernel (rustls / aws-lc-rs)
```rust
let mut config = rustls::ServerConfig::builder()
    .with_cipher_suites(&[
        TLS_AES_256_GCM_SHA384,
        TLS_CHACHA20_POLY1305_SHA256,
    ])
    .with_kx_groups(&[
        X25519_MLKEM768,
        TLS_MLKEM768,
        X25519,
    ])
    .with_protocol_versions(&[&TLS13])
    .unwrap();
```

### Python / Julia (OQS Provider)
- OQS-OpenSSL 3 provider for OpenSSL-based applications
- liboqs for direct integration
- curl with OQS support for HTTP clients
- Python: cryptography + oqs-python
- Julia: QuantumCryptography.jl with liboqs bindings

## Certificate Management

### Chain Structure
```
Root CA (SLH-DSA-256f, offline HSM, 10-year validity)
  └── Intermediate CA (ML-DSA-87, online HSM, 5-year)
       ├── Station Identity (SLH-DSA-192s, 12-month)
       │     └── Session Certificate (ML-DSA-65, hybrid with Ed25519, 90-day)
       ├── Service mTLS (ML-DSA-65, 90-day)
       └── Receipt Signing Authority (ML-DSA-87, 6-month)
```

### cert-manager Integration
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dgsn-mtls-crypto
spec:
  secretName: dgsn-crypto-tls
  duration: 2160h  # 90 days
  renewBefore: 360h  # 15 days
  privateKey:
    algorithm: ECDSA
    size: 384
  usages:
    - server auth
    - client auth
  dnsNames:
    - crypto-kernel.dgsn.svc.cluster.local
  issuerRef:
    name: dgsn-pqc-issuer
    kind: ClusterIssuer
```

## Key Rotation

### Rotation Schedule
| Key Type | Algorithm | Rotation Period | Auto/Manual |
|----------|-----------|----------------|-------------|
| Root CA | SLH-DSA-256f | 10 years | Manual (ceremony) |
| Intermediate CA | ML-DSA-87 | 5 years | Manual |
| Station identity | SLH-DSA-192s | 12 months | Automated |
| Session keys | ML-KEM-768 | Per-session | Automatic |
| Receipt signing | ML-DSA-65 | 6 months | Automated |
| API keys | N/A | 90 days | Automated |
| Database creds | N/A | 24h (dynamic) | Automatic |

### Automated Rotation via cert-manager
1. cert-manager monitors certificate expiry
2. 15 days before expiry, new certificate requested
3. New certificate stored alongside old (rotation window)
4. Service picks up new cert via file watch or SIGHUP
5. Old certificate revoked after 24h grace period
6. Metrics updated: `dgsn_tls_cert_expiry_days`

### Manual Rotation Steps
For keys that cannot be auto-rotated (root CA, identity keys):
1. Schedule maintenance window
2. Generate new keypair offline on HSM
3. Sign transition document with old key
4. Distribute new public key to all services
5. Verify transition with `dgsn-crypto-cli verify-transition`
6. Activate new key
7. Monitor for verification failures

## Supported Ciphersuites

### TLS 1.3 Ciphersuites
| Ciphersuite | Algorithm | Priority | Status |
|------------|-----------|----------|--------|
| TLS_AES_256_GCM_SHA384 | AES-256-GCM | Primary | Enabled |
| TLS_CHACHA20_POLY1305_SHA256 | ChaCha20-Poly1305 | Fallback | Enabled |
| TLS_AES_128_GCM_SHA256 | AES-128-GCM | Low | Enabled (compatibility) |

### Hybrid Key Exchange (PQC + Classical)
| KEM Group | PQC | Classical | Priority |
|-----------|-----|-----------|----------|
| X25519_MLKEM768 | ML-KEM-768 | X25519 | Primary |
| P384_MLKEM1024 | ML-KEM-1024 | secp384r1 | High-security |
| X25519 | None | X25519 | Fallback |

### Signature Algorithms
| Algorithm | Type | Priority | Status |
|-----------|------|----------|--------|
| MLDSA65 | PQC | Primary | Enabled |
| Ed25519 + MLDSA65 | Hybrid (dual) | Preferred | Enabled |
| Ed25519 | Classical | Fallback | Enabled |
| ecdsa_secp384r1_sha384 | Classical | Low | Compatibility |

## Monitoring PQC Operations

### Prometheus Metrics
```prometheus
# Algorithm usage
dgsn_crypto_operations_total{algorithm="ML-DSA-65", operation="sign"}
dgsn_crypto_operations_total{algorithm="ML-KEM-768", operation="encapsulate"}
dgsn_crypto_operations_total{algorithm="SLH-DSA-192s", operation="sign"}

# Operation latency (histograms)
dgsn_crypto_sign_duration_seconds_bucket{algorithm="ML-DSA-65"}
dgsn_crypto_verify_duration_seconds_bucket{algorithm="SLH-DSA-192s"}
dgsn_crypto_keygen_duration_seconds_bucket{algorithm="ML-KEM-768"}

# Error tracking
dgsn_crypto_errors_total{algorithm="ML-DSA-65", error_type="verification"}
dgsn_crypto_keygen_failures_total
dgsn_crypto_verify_failures_total
dgsn_crypto_rotation_status{algorithm="ML-DSA-65"}

# Key lifecycle
dgsn_pqc_key_age_days{algorithm="ML-DSA-65"}
dgsn_pqc_key_expiry_days{algorithm="SLH-DSA-192s"}
```

### Grafana Dashboards
- `configs/grafana/dashboards/security-events.json` - PQC operation monitoring
- `configs/grafana/dashboards/quantum-metrics.json` - Circuit performance

## NIST CNSA 2.0 Compliance

DGSN aligns with the Commercial National Security Algorithm Suite 2.0:

### Required Algorithms
| CNSA 2.0 Requirement | DGSN Implementation | Status |
|----------------------|-------------------|--------|
| ML-KEM-768 (KEM) | Session key exchange | ✅ |
| ML-DSA-65 (Signatures) | Receipt signing | ✅ |
| SLH-DSA-192s (Signatures) | Station identity | ✅ |
| AES-256 (Symmetric) | Data at rest | ✅ |
| SHA-384 (Hashing) | Receipt hashing | ✅ |

### CNSA 2.0 Compliance Exceptions
- TLS handshake: Hybrid (X25519 + ML-KEM-768) until PQC-only migration
- Legacy interop: Ed25519 fallback for external partners
- Browser-facing: Classical ECDSA until browser support matures

## Performance Characteristics

| Operation | ML-DSA-44 | ML-DSA-65 | ML-DSA-87 | SLH-DSA-128f | SLH-DSA-192s | SLH-DSA-256f | ML-KEM-512 | ML-KEM-768 | ML-KEM-1024 |
|-----------|-----------|-----------|-----------|--------------|--------------|--------------|------------|------------|-------------|
| Keygen | ~0.3ms | ~0.5ms | ~0.8ms | ~15ms | ~20ms | ~30ms | ~0.2ms | ~0.3ms | ~0.5ms |
| Sign/Encaps | ~0.5ms | ~0.8ms | ~1.2ms | ~10ms | ~15ms | ~25ms | ~0.3ms | ~0.4ms | ~0.6ms |
| Verify/Decaps | ~0.2ms | ~0.3ms | ~0.5ms | ~0.8ms | ~1ms | ~1.5ms | ~0.2ms | ~0.3ms | ~0.4ms |

## Troubleshooting

### Common Issues
1. **Key size mismatch**: Verify raw key length matches expected algorithm parameters
2. **Signature too large**: SLH-DSA signatures are large (up to ~50KB); may exceed gRPC message limits
3. **Performance degradation**: Profile with `dgsn-crypto-cli benchmark`; consider ML-DSA-44 for high-throughput
4. **Randomness failures**: Ensure sufficient entropy (`/dev/urandom availability`); HSM provides TRNG
5. **WASM compatibility**: Use `wasm` feature flag for browser targets; SLH-DSA may be too slow
6. **Certificate chain too large**: PQC certs can be 5-50KB; tune `max_verify_depth` and buffer sizes
7. **Interop failures**: Verify OQS provider version matches across services

### Debug Commands
```bash
# Check key validity and algorithm parameters
dgsn-crypto-cli inspect-key /etc/dgsn/keys/active/pk.bin

# Verify algorithm support and available implementations
dgsn-crypto-cli list-algorithms

# Run crypto benchmarks (1000 iterations)
dgsn-crypto-cli benchmark --operations 1000

# Test mTLS connectivity
dgsn-crypto-cli ping --endpoint crypto-kernel:50050

# Verify PQC certificate chain
dgsn-crypto-cli verify-chain --cert /etc/dgsn/certs/chain.pem

# Check rotation status
dgsn-crypto-cli rotation-status --algorithm ML-DSA-65
```
