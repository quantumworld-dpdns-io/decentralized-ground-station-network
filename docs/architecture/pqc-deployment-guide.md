# Post-Quantum Cryptography Deployment Guide

## Overview

This guide covers deployment and operation of post-quantum cryptography (PQC) in DGSN, including algorithm selection, key management, migration paths, and operational procedures.

## Supported Algorithms

### FIPS 203: ML-KEM (Kyber)
- **ML-KEM-512**: 128-bit security, NIST Level 1
- **ML-KEM-768**: 192-bit security, NIST Level 3 (default)
- **ML-KEM-1024**: 256-bit security, NIST Level 5

### FIPS 204: ML-DSA (Dilithium)
- **ML-DSA-44**: 128-bit security, ~2.5KB signature
- **ML-DSA-65**: 192-bit security, ~3.3KB signature (default)
- **ML-DSA-87**: 256-bit security, ~4.6KB signature

### FIPS 205: SLH-DSA (SPHINCS+)
- **SLH-DSA-128f**: 128-bit security, fast verification
- **SLH-DSA-192s**: 192-bit security, small signature (default for identity)
- **SLH-DSA-256f**: 256-bit security, fast verification

## Algorithm Selection Guide

| Use Case | Algorithm | Rationale |
|----------|-----------|-----------|
| Receipt signing | ML-DSA-65 | Balance of speed and security |
| Station identity | SLH-DSA-192s | Stateless, long-term security |
| Session establishment | ML-KEM-768 | NIST standard, efficient |
| Data at rest | ML-KEM-1024 + AES-256-GCM | Hybrid encryption |
| ZKP circuits | ML-DSA-44 | Faster proving time |
| Audit trail | SLH-DSA-256f | Maximum long-term security |

## Hybrid Migration Path

### Phase 1: Classical + PQC (Current)
```
TLS 1.3 + X25519 + ML-KEM-768
Ed25519 + ML-DSA-65 (dual signatures)
```

### Phase 2: PQC Preferred
```
TLS 1.3 + ML-KEM-768 (X25519 as fallback)
ML-DSA-65 (Ed25519 as fallback)
```

### Phase 3: PQC Only
```
ML-KEM-768 exclusively
ML-DSA-65 exclusively
SLH-DSA-192s for long-term identity
```

## Key Generation

### Rust Crypto Kernel

```rust
use dgsn_crypto_kernel::pqc::{Algorithm, keygen, sign, verify};

// Generate ML-DSA-65 keypair
let (pk, sk) = keygen(Algorithm::MLDSA65)?;

// Sign a receipt
let receipt = b"station=gs-01&satellite=ISS&timestamp=1718000000";
let signature = sign(&Algorithm::MLDSA65, receipt, &sk)?;

// Verify
let valid = verify(&Algorithm::MLDSA65, receipt, &signature, &pk)?;
```

### CLI Tool

```bash
# Generate keys
dgsn-crypto-cli keygen --algorithm ML-DSA-65 --output /etc/dgsn/keys/

# Sign data
dgsn-crypto-cli sign \
  --algorithm ML-DSA-65 \
  --key /etc/dgsn/keys/receipt-sk.bin \
  --input receipt.json \
  --output receipt.sig

# Verify
dgsn-crypto-cli verify \
  --algorithm ML-DSA-65 \
  --key /etc/dgsn/keys/receipt-pk.bin \
  --input receipt.json \
  --signature receipt.sig
```

## Key Rotation

### Receipt Signing Keys
Rotation every 6 months:

```bash
# 1. Generate new keypair
dgsn-crypto-cli keygen --algorithm ML-DSA-65 --output /etc/dgsn/keys/new/

# 2. Sign transition document
dgsn-crypto-cli sign \
  --algorithm SLH-DSA-192s \
  --key /etc/dgsn/keys/identity-sk.bin \
  --input /etc/dgsn/keys/new/pk.bin \
  --output transition.sig

# 3. Distribute new public key
dgsn-crypto-cli publish-key \
  --key /etc/dgsn/keys/new/pk.bin \
  --transition-signature transition.sig

# 4. Verify transition
dgsn-crypto-cli verify-transition \
  --old-key /etc/dgsn/keys/old/pk.bin \
  --new-key /etc/dgsn/keys/new/pk.bin \
  --identity-key /etc/dgsn/keys/identity-pk.bin

# 5. Activate new key
mv /etc/dgsn/keys/new/sk.bin /etc/dgsn/keys/active/sk.bin
mv /etc/dgsn/keys/new/pk.bin /etc/dgsn/keys/active/pk.bin
```

## Performance Characteristics

| Operation | ML-DSA-65 | SLH-DSA-192s | ML-KEM-768 |
|-----------|-----------|--------------|------------|
| Key generation | ~0.5ms | ~20ms | ~0.3ms |
| Sign/Encaps | ~0.8ms | ~15ms | ~0.4ms |
| Verify/Decaps | ~0.3ms | ~1ms | ~0.3ms |
| Public key size | 1,952 bytes | 96 bytes | 1,184 bytes |
| Secret key size | 4,000 bytes | 96 bytes | 2,400 bytes |
| Signature/CT size | 3,309 bytes | 47,552 bytes | 1,089 bytes |

## Monitoring

### Prometheus Metrics

```prometheus
# Algorithm usage
dgsn_crypto_operations_total{algorithm="ML-DSA-65", operation="sign"}
dgsn_crypto_operations_total{algorithm="ML-KEM-768", operation="encapsulate"}

# Operation latency
dgsn_crypto_sign_duration_seconds_bucket{algorithm="ML-DSA-65"}
dgsn_crypto_verify_duration_seconds_bucket{algorithm="SLH-DSA-192s"}
dgsn_crypto_keygen_duration_seconds_bucket{algorithm="ML-KEM-768"}

# Error tracking
dgsn_crypto_errors_total{algorithm="ML-DSA-65", error_type="verification"}
dgsn_crypto_keygen_failures_total
dgsn_crypto_verify_failures_total
```

### Grafana Dashboard

See `configs/grafana/dashboards/security-events.json` for PQC operation monitoring.

## Troubleshooting

### Common Issues

1. **Key size mismatch**: Verify raw key length matches expected algorithm size
2. **Signature too large**: SLH-DSA signatures are large (~47KB for 192s)
3. **Performance degradation**: Review key sizes and consider ML-DSA-44 for high-throughput scenarios
4. **Randomness failures**: Ensure sufficient entropy (/dev/urandom available)
5. **WASM compatibility**: Use `wasm` feature flag for browser targets

### Debug Commands

```bash
# Check key validity
dgsn-crypto-cli inspect-key /etc/dgsn/keys/active/pk.bin

# Verify algorithm support
dgsn-crypto-cli list-algorithms

# Run crypto benchmarks
dgsn-crypto-cli benchmark --operations 1000

# Test network connectivity
dgsn-crypto-cli ping --endpoint crypto-kernel:50050
```
