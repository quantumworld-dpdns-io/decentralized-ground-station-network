# PQC Key Rotation Procedure

## Overview

This runbook covers rotation of post-quantum cryptographic keys used in DGSN. Key rotation is critical for maintaining security posture and CNSA 2.0 compliance.

## Rotation Schedule

| Key Type | Algorithm | Rotation Period | Auto/Manual | Service Impact |
|----------|-----------|----------------|-------------|---------------|
| Root CA | SLH-DSA-256f | 10 years | Manual (ceremony) | None (offline) |
| Intermediate CA | ML-DSA-87 | 5 years | Manual | None (overlap window) |
| Station identity | SLH-DSA-192s | 12 months | Automated cert-manager | None |
| Session (ephemeral) | ML-KEM-768 | Per-session | Automatic | None |
| Receipt signing | ML-DSA-65 | 6 months | Automated | Brief verification delay |
| API keys | - | 90 days | Automated (Vault) | None |
| Database creds | - | 24h (dynamic) | Automatic | None |
| TLS certificates | ECDSA + ML-DSA | 90 days | Automated cert-manager | None |

## Automated Rotation via cert-manager

### TLS Certificates (90 days)
cert-manager handles TLS certificate rotation automatically:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dgsn-mtls-crypto
  namespace: dgsn
spec:
  secretName: dgsn-crypto-tls
  duration: 2160h  # 90 days
  renewBefore: 360h  # 15 days before expiry
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

### Verification
```bash
# Check certificate expiry
kubectl get certificate -n dgsn -o wide

# Check renewal status
kubectl describe certificate dgsn-mtls-crypto -n dgsn

# Verify metrics
curl http://prometheus:9090/api/v1/query?query=dgsn_tls_cert_expiry_days
```

## Automated PQC Key Rotation (ML-DSA-65)

### Pre-Rotation Checks
```bash
# 1. Verify current key status
dgsn-crypto-cli rotation-status --algorithm ML-DSA-65

# 2. Check key age
curl http://prometheus:9090/api/v1/query?query=dgsn_pqc_key_age_days{algorithm="ML-DSA-65"}

# 3. Verify all nodes healthy
kubectl get pods -n dgsn -l app=dgsn-crypto-kernel

# 4. Confirm no ongoing incidents
# Check #dgsn-alerts for active incidents
```

### Automated Rotation Steps
```bash
#!/bin/bash
# This script is run by a CronJob in Kubernetes

set -euo pipefail

ALGORITHM="ML-DSA-65"
KEY_DIR="/etc/dgsn/keys"
NEW_KEY_DIR="${KEY_DIR}/new"
ACTIVE_KEY_DIR="${KEY_DIR}/active"
OLD_KEY_DIR="${KEY_DIR}/old"
IDENTITY_KEY="${KEY_DIR}/identity-sk.bin"

echo "=== PQC Key Rotation: ${ALGORITHM} ==="

# Step 1: Generate new keypair
echo "Generating new keypair..."
dgsn-crypto-cli keygen \
  --algorithm ${ALGORITHM} \
  --output ${NEW_KEY_DIR}/

# Step 2: Sign transition document with identity key
echo "Signing transition document..."
dgsn-crypto-cli sign \
  --algorithm SLH-DSA-192s \
  --key ${IDENTITY_KEY} \
  --input ${NEW_KEY_DIR}/pk.bin \
  --output ${NEW_KEY_DIR}/transition.sig

# Step 3: Distribute new public key
echo "Publishing new public key..."
dgsn-crypto-cli publish-key \
  --key ${NEW_KEY_DIR}/pk.bin \
  --transition-signature ${NEW_KEY_DIR}/transition.sig

# Step 4: Verify transition
echo "Verifying transition..."
dgsn-crypto-cli verify-transition \
  --old-key ${ACTIVE_KEY_DIR}/pk.bin \
  --new-key ${NEW_KEY_DIR}/pk.bin \
  --identity-key ${KEY_DIR}/identity-pk.bin

# Step 5: Archive old key
echo "Archiving old key..."
mkdir -p ${OLD_KEY_DIR}/$(date +%Y%m%d-%H%M%S)
mv ${ACTIVE_KEY_DIR}/* ${OLD_KEY_DIR}/$(date +%Y%m%d-%H%M%S)/

# Step 6: Activate new key
echo "Activating new key..."
cp ${NEW_KEY_DIR}/sk.bin ${ACTIVE_KEY_DIR}/sk.bin
cp ${NEW_KEY_DIR}/pk.bin ${ACTIVE_KEY_DIR}/pk.bin

# Step 7: Signal services to reload keys
echo "Signaling services..."
kubectl rollout restart -n dgsn deployment/dgsn-backend
kubectl rollout restart -n dgsn deployment/dgsn-crypto-kernel

# Step 8: Verify active signing
echo "Verifying new key signing..."
dgsn-crypto-cli sign \
  --algorithm ${ALGORITHM} \
  --key ${ACTIVE_KEY_DIR}/sk.bin \
  --input /tmp/test-message \
  --output /tmp/test-signature

dgsn-crypto-cli verify \
  --algorithm ${ALGORITHM} \
  --key ${ACTIVE_KEY_DIR}/pk.bin \
  --input /tmp/test-message \
  --signature /tmp/test-signature

echo "=== Rotation Complete ==="
rm -f /tmp/test-message /tmp/test-signature
```

## Manual Rotation Procedure

### When Manual Rotation is Required
- Root CA or intermediate CA rotation
- Key compromise scenario
- Automated rotation failure
- Algorithm migration (e.g., ML-DSA-65 → ML-DSA-87)

### Preparation (1 week before)
```bash
# 1. Schedule maintenance window
echo "Schedule: 2-hour window, 3-hour buffer"

# 2. Generate new keypair offline (HSM)
echo "Using HSM for secure key generation..."
dgsn-crypto-cli keygen \
  --algorithm ML-DSA-65 \
  --hsm-slot 0 \
  --output /backup/new-keys/

# 3. Print new public key QR code for physical backup
dgsn-crypto-cli qr-key /backup/new-keys/pk.bin
```

### Rotation Window Steps
```bash
# 1. Enable maintenance mode
kubectl apply -f configs/maintenance-mode.yaml

# 2. Backup current keys
echo "Backing up current keys..."
tar czf /backup/keys-$(date +%Y%m%d).tgz /etc/dgsn/keys/
gpg --encrypt --recipient dgsn-backup /backup/keys-*.tgz

# 3. Deploy new keys
echo "Deploying new keys..."
kubectl create secret generic dgsn-crypto-keys-new \
  --from-file=/backup/new-keys/

# 4. Generate transition certificate
echo "Generating transition cert..."
dgsn-crypto-cli sign-transition \
  --old-key /etc/dgsn/keys/active/pk.bin \
  --new-key /backup/new-keys/pk.bin \
  --identity-key /etc/dgsn/keys/identity-sk.bin

# 5. Verify transition
echo "Verifying transition..."
dgsn-crypto-cli verify-transition \
  --old-key /etc/dgsn/keys/active/pk.bin \
  --new-key /backup/new-keys/pk.bin \
  --identity-key /etc/dgsn/keys/identity-pk.bin

# 6. Activate new keys
echo "Activating..."
kubectl apply -f configs/activate-new-keys.yaml

# 7. Restart services
kubectl rollout restart -n dgsn deployment/dgsn-crypto-kernel
kubectl rollout restart -n dgsn deployment/dgsn-backend

# 8. Verify operation
echo "Verifying..."
dgsn-crypto-cli health --endpoint crypto-kernel:50051
curl http://backend:8080/health

# 9. Disable maintenance mode
kubectl delete -f configs/maintenance-mode.yaml
```

## Rollback Plan

### Automated Rollback (within rotation window)
```bash
# 1. Restore previous key
echo "Restoring previous key..."
cp -r /etc/dgsn/keys/old/$(ls -t /etc/dgsn/keys/old/ | head -1)/* \
  /etc/dgsn/keys/active/

# 2. Signal services to reload keys
kubectl rollout restart -n dgsn deployment/dgsn-backend
kubectl rollout restart -n dgsn deployment/dgsn-crypto-kernel

# 3. Verify rollback
dgsn-crypto-cli health --endpoint crypto-kernel:50051
curl http://backend:8080/health
```

### Manual Rollback (after rotation window)
```bash
# 1. Restore from backup
tar xzf /backup/keys-$(date +%Y%m%d).tgz
gpg --decrypt /backup/keys-*.tgz.gpg > /tmp/keys.tar.gz

# 2. Restore to all crypto pods
kubectl cp /tmp/keys.tar.gz dgsn-crypto-kernel-0:/tmp/
kubectl exec dgsn-crypto-kernel-0 -- tar xzf /tmp/keys.tar.gz -C /etc/dgsn/keys/

# 3. Restart services
kubectl rollout restart -n dgsn deployment/dgsn-crypto-kernel
kubectl rollout restart -n dgsn deployment/dgsn-backend
```

## Verification Steps

### Post-Rotation Verification
```bash
# 1. Check key age metric
curl http://prometheus:9090/api/v1/query?query=dgsn_pqc_key_age_days

# 2. Test sign and verify
dgsn-crypto-cli sign \
  --algorithm ML-DSA-65 \
  --key /etc/dgsn/keys/active/sk.bin \
  --input /tmp/verify-test \
  --output /tmp/verify-test.sig

dgsn-crypto-cli verify \
  --algorithm ML-DSA-65 \
  --key /etc/dgsn/keys/active/pk.bin \
  --input /tmp/verify-test \
  --signature /tmp/verify-test.sig

# 3. Verify receipt creation
curl -X POST http://backend:8080/api/v1/receipts/test \
  -H "Content-Type: application/json" \
  -d '{"station":"gs-test","test":true}'

# 4. Check Grafana dashboard for PQC metrics
open https://grafana.dgsn.example.com/d/dgsn-security

# 5. Verify alert rules not firing
curl http://prometheus:9090/api/v1/alerts
```

## Communication Plan

### Pre-Rotation (1 week before)
- Email: dgsn-team@ with rotation schedule
- Slack: #dgsn-announcement with maintenance window
- Status page: Update maintenance calendar

### During Rotation
- Slack: #dgsn-incident with live status updates
- PagerDuty: Suppress non-critical alerts
- Status page: Mark as "Under Maintenance"

### Post-Rotation
- Email: dgsn-team@ with rotation results
- Slack: #dgsn-announcement with completion notice
- Status page: Clear maintenance status

## Monitoring After Rotation

### Immediate (first 15 minutes)
- Monitor crypto error rate: `dgsn_crypto_errors_total`
- Monitor verification success rate: `dgsn:receipt_verification_success_rate_5m`
- Check all services healthy: `up == 0`

### Short-term (first 24 hours)
- Monitor key usage by algorithm: `dgsn_crypto_operations_total`
- Check for certificate expiry warnings
- Verify no increase in auth failures

### Long-term (30 days)
- Track key age for next rotation
- Review rotation logs for anomalies
- Update rotation schedule
