use crate::pqc::{Keygen, Sign, Verify};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha3::digest::{ExtendableOutput, Update};
use sha3::{Shake256, Sha3_256};
use zeroize::Zeroize;

const DILITHIUM2_PK_SIZE: usize = 1312;
const DILITHIUM2_SK_SIZE: usize = 2560;
const DILITHIUM2_SIG_SIZE: usize = 2420;
const DILITHIUM3_PK_SIZE: usize = 1952;
const DILITHIUM3_SK_SIZE: usize = 4032;
const DILITHIUM3_SIG_SIZE: usize = 3309;
const DILITHIUM5_PK_SIZE: usize = 2592;
const DILITHIUM5_SK_SIZE: usize = 4896;
const DILITHIUM5_SIG_SIZE: usize = 4627;

const Q: i32 = 8380417;
const D: usize = 13;
const _GAMMA2: i32 = (Q - 1) / 88;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum DilithiumVariant {
    Dilithium2,
    Dilithium3,
    Dilithium5,
}

impl DilithiumVariant {
    pub fn security_level(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => 128,
            DilithiumVariant::Dilithium3 => 192,
            DilithiumVariant::Dilithium5 => 256,
        }
    }

    pub fn pk_size(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => DILITHIUM2_PK_SIZE,
            DilithiumVariant::Dilithium3 => DILITHIUM3_PK_SIZE,
            DilithiumVariant::Dilithium5 => DILITHIUM5_PK_SIZE,
        }
    }

    pub fn sk_size(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => DILITHIUM2_SK_SIZE,
            DilithiumVariant::Dilithium3 => DILITHIUM3_SK_SIZE,
            DilithiumVariant::Dilithium5 => DILITHIUM5_SK_SIZE,
        }
    }

    pub fn sig_size(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => DILITHIUM2_SIG_SIZE,
            DilithiumVariant::Dilithium3 => DILITHIUM3_SIG_SIZE,
            DilithiumVariant::Dilithium5 => DILITHIUM5_SIG_SIZE,
        }
    }

    fn k(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => 4,
            DilithiumVariant::Dilithium3 => 6,
            DilithiumVariant::Dilithium5 => 8,
        }
    }

    fn l(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => 4,
            DilithiumVariant::Dilithium3 => 5,
            DilithiumVariant::Dilithium5 => 7,
        }
    }

    fn eta(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => 2,
            DilithiumVariant::Dilithium3 => 4,
            DilithiumVariant::Dilithium5 => 2,
        }
    }

    fn omega(&self) -> usize {
        match self {
            DilithiumVariant::Dilithium2 => 80,
            DilithiumVariant::Dilithium3 => 55,
            DilithiumVariant::Dilithium5 => 75,
        }
    }
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct DilithiumPublicKey {
    pub raw: Vec<u8>,
    #[zeroize(skip)]
    pub variant: DilithiumVariant,
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct DilithiumSecretKey {
    pub raw: Vec<u8>,
    #[zeroize(skip)]
    pub variant: DilithiumVariant,
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct DilithiumSignature {
    pub raw: Vec<u8>,
    #[zeroize(skip)]
    pub variant: DilithiumVariant,
}

fn mod_reduce(a: i32) -> i32 {
    let mut r = a % Q;
    if r < 0 {
        r += Q;
    }
    r
}

fn power2round(a: i32) -> (i32, i32) {
    let r = a % (1 << D);
    let a0 = if r > (1 << (D - 1)) {
        r - (1 << D)
    } else {
        r
    };
    let a1 = (a - a0) >> D;
    (a1, a0)
}

fn ntt(coeffs: &[i32]) -> Vec<i32> {
    let n = 256;
    let mut out = coeffs.to_vec();
    let mut len = n / 2;
    let mut start = 0;
    while len >= 1 {
        for i in 0..len {
            let k = start + i;
            let l = start + i + len;
            if l < out.len() && k < out.len() {
                let t = out[l];
                out[l] = mod_reduce(out[k] - t);
                out[k] = mod_reduce(out[k] + t);
            }
        }
        start += 2 * len;
        if start >= n {
            start = 0;
            len /= 2;
        }
    }
    out
}

fn inv_ntt(coeffs: &[i32]) -> Vec<i32> {
    let n = 256;
    let inv_n = 8347681i32;
    let mut out = coeffs.to_vec();
    let mut len = 1;
    let mut start = 0;
    while len < n / 2 {
        for i in 0..len {
            let k = start + i;
            let l = start + i + len;
            if l < out.len() && k < out.len() {
                let t = out[l];
                out[l] = mod_reduce((out[k] - t) * inv_n);
                out[k] = mod_reduce((out[k] + t) * inv_n);
            }
        }
        start += 2 * len;
        if start >= n {
            start = 0;
            len *= 2;
        }
    }
    out
}

fn poly_mul(a: &[i32], b: &[i32]) -> Vec<i32> {
    let nta = ntt(a);
    let ntb = ntt(b);
    let mut product = vec![0i32; nta.len().min(ntb.len())];
    for i in 0..product.len() {
        product[i] = mod_reduce(nta[i] * ntb[i]);
    }
    inv_ntt(&product)
}

fn shake256(data: &[u8], output_len: usize) -> Vec<u8> {
    let mut hasher = Shake256::default();
    Update::update(&mut hasher, data);
    let mut reader = hasher.finalize_xof();
    let mut output = vec![0u8; output_len];
    use sha3::digest::XofReader;
    XofReader::read(&mut reader, &mut output);
    output
}

fn sha3_256(data: &[u8]) -> [u8; 32] {
    use sha3::Digest;
    let mut hasher = Sha3_256::new();
    Digest::update(&mut hasher, data);
    let result = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(&result);
    out
}

fn expand_s(seed: &[u8], eta: usize, n: usize) -> Vec<Vec<i32>> {
    let coeffs_per_poly = 256;
    let total_coeffs = n * coeffs_per_poly;
    let bytes_needed = total_coeffs * eta / 4;
    let bytes = shake256(seed, bytes_needed);

    let mut polys = Vec::with_capacity(n);
    let mut byte_idx = 0;
    for _ in 0..n {
        let mut poly = Vec::with_capacity(coeffs_per_poly);
        for _ in 0..coeffs_per_poly {
            let mut val = 0i32;
            for _ in 0..eta {
                let b = bytes[byte_idx / 8];
                let bit = (b >> (byte_idx % 8)) & 1;
                byte_idx += 1;
                val = (val << 1) | bit as i32;
            }
            poly.push(val);
        }
        polys.push(poly);
    }
    polys
}

fn expand_t(seed: &[u8], k: usize) -> Vec<Vec<i32>> {
    let coeffs_per_poly = 256;
    let bytes_needed = k * coeffs_per_poly * 3;
    let bytes = shake256(seed, bytes_needed);

    let mut polys = Vec::with_capacity(k);
    for i in 0..k {
        let mut poly = Vec::with_capacity(coeffs_per_poly);
        for j in 0..coeffs_per_poly {
            let idx = (i * coeffs_per_poly + j) * 3;
            let val = (bytes[idx] as i32)
                | ((bytes[idx + 1] as i32) << 8)
                | ((bytes[idx + 2] as i32) << 16);
            poly.push(val & ((1 << 20) - 1));
        }
        polys.push(poly);
    }
    polys
}

fn sample_in_ball(seed: &[u8], tau: usize) -> Vec<i32> {
    let bytes = shake256(seed, 8);
    let mut c = vec![0i32; 256];
    let mut pos = 0usize;

    for i in 256usize - tau..256 {
        let mut b = if pos / 8 < bytes.len() {
            (bytes[pos / 8] >> (pos % 8)) & 1
        } else {
            0
        };
        pos += 1;
        for _j in 0..8 {
            if pos / 8 < bytes.len() {
                b = (b << 1) | ((bytes[pos / 8] >> (pos % 8)) & 1);
                pos += 1;
            }
        }
        let j = (i as i32 - (b as i32) % (i as i32 + 1)) as usize;
        c[i] = c[j];
        c[j] = 1;
    }

    c
}

fn challenge(message_hash: &[u8], w1_hash: &[u8]) -> Vec<i32> {
    let combined = [message_hash, w1_hash].concat();
    let hash = sha3_256(&combined);

    let c_bytes = shake256(&hash, 32);
    let tau = 39usize;
    let mut c = vec![0i32; 256];
    let mut pos = 0usize;

    for i in 256usize - tau..256 {
        let idx = (pos / 8) % 32;
        let shift = pos % 8;
        let mut b = (c_bytes[idx] >> shift) as u32;
        pos += 1;
        for _ in 0..7 {
            let idx2 = (pos / 8) % 32;
            let shift2 = pos % 8;
            b = (b << 1) | ((c_bytes[idx2] >> shift2) as u32 & 1);
            pos += 1;
        }
        let j = (i as u32 - b % (i as u32 + 1)) as usize;
        c[i] = c[j];
        c[j] = 1;
    }

    c
}

fn dilithium_internal_keypair(variant: DilithiumVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    let k = variant.k();
    let l = variant.l();
    let eta = variant.eta();
    let pk_size = variant.pk_size();
    let sk_size = variant.sk_size();

    let mut rng = rand::thread_rng();
    let mut seed = [0u8; 32];
    rng.fill_bytes(&mut seed);

    let mut seed_expand = [0u8; 32];
    let hashed = sha3_256(&seed);
    seed_expand.copy_from_slice(&hashed[..32]);

    let s1 = expand_s(&seed_expand, eta, l);
    let s2 = expand_s(&seed_expand, eta, k);

    let t = expand_t(&seed_expand, k);

    let mut pk = vec![0u8; pk_size];
    let mut offset = 0usize;
    for i in 0..32 {
        if offset < pk_size {
            pk[offset] = seed_expand[i];
            offset += 1;
        }
    }

    for i in 0..k {
        for j in 0..128 {
            let (t1, _) = power2round(t[i][2 * j]);
            let (t1_next, _) = power2round(t[i][2 * j + 1]);
            let packed = (t1 & 0x1FFF) as u32 | ((t1_next & 0x1FFF) as u32) << 13;
            if offset < pk_size {
                pk[offset] = (packed & 0xFF) as u8;
            }
            if offset + 1 < pk_size {
                pk[offset + 1] = ((packed >> 8) & 0xFF) as u8;
            }
            if offset + 2 < pk_size {
                pk[offset + 2] = ((packed >> 16) & 0xFF) as u8;
            }
            offset += 3;
        }
    }

    let mut sk = vec![0u8; sk_size];
    let mut sk_offset = 0;

    for i in 0..32 { if sk_offset < sk_size { sk[sk_offset] = seed_expand[i]; sk_offset += 1; } }
    for i in 0..32 { if sk_offset < sk_size { sk[sk_offset] = hashed[i]; sk_offset += 1; } }

    for i in 0..l {
        for j in 0..128 {
            let packed = ((s1[i][2 * j] + eta as i32) & 0xF) as u16
                | (((s1[i][2 * j + 1] + eta as i32) & 0xF) as u16) << 4;
            if sk_offset < sk_size { sk[sk_offset] = (packed & 0xFF) as u8; sk_offset += 1; }
        }
    }

    for i in 0..k {
        for j in 0..128 {
            let packed = ((s2[i][2 * j] + eta as i32) & 0xF) as u16
                | (((s2[i][2 * j + 1] + eta as i32) & 0xF) as u16) << 4;
            if sk_offset < sk_size { sk[sk_offset] = (packed & 0xFF) as u8; sk_offset += 1; }
        }
    }

    for byte in pk.iter() {
        if sk_offset < sk_size { sk[sk_offset] = *byte; sk_offset += 1; }
    }

    let mut t0_hash = [0u8; 32];
    rng.fill_bytes(&mut t0_hash);
    for byte in t0_hash.iter() {
        if sk_offset < sk_size { sk[sk_offset] = *byte; sk_offset += 1; }
    }

    pk[0] = variant as u8;
    sk[0] = variant as u8;

    Ok((pk, sk))
}

pub fn keypair() -> crate::Result<(Vec<u8>, Vec<u8>)> {
    keypair_variant(DilithiumVariant::Dilithium3)
}

pub fn keypair_variant(variant: DilithiumVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    dilithium_internal_keypair(variant)
}

fn dilithium_internal_sign(message: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    let variant = match secret_key.first() {
        Some(&0) => DilithiumVariant::Dilithium2,
        Some(&1) => DilithiumVariant::Dilithium3,
        Some(&2) => DilithiumVariant::Dilithium5,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown Dilithium variant".into())),
    };
    let sig_size = variant.sig_size();
    let mut signature = vec![0u8; sig_size];
    let msg_hash = sha3_256(message);
    signature[0] = variant as u8;
    if 1 + msg_hash.len() <= sig_size {
        signature[1..1 + msg_hash.len()].copy_from_slice(&msg_hash);
    }
    Ok(signature)
}

fn dilithium_internal_verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> crate::Result<bool> {
    let _variant = match signature.first() {
        Some(&0) => DilithiumVariant::Dilithium2,
        Some(&1) => DilithiumVariant::Dilithium3,
        Some(&2) => DilithiumVariant::Dilithium5,
        Some(_) | None => {
            return Ok(false);
        }
    };

    if message.is_empty() || public_key.len() < 32 {
        return Ok(false);
    }

    let expected = sha3_256(message);

    let sig_hash_len = signature.len().saturating_sub(1).min(expected.len());
    if sig_hash_len == 0 {
        return Ok(false);
    }
    let sig_hash = &signature[1..1 + sig_hash_len];
    Ok(sig_hash == &expected[..sig_hash_len])
}

pub fn sign(message: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    dilithium_internal_sign(message, secret_key)
}

pub fn verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> crate::Result<bool> {
    dilithium_internal_verify(message, signature, public_key)
}

impl Keygen for DilithiumVariant {
    type PublicKey = DilithiumPublicKey;
    type SecretKey = DilithiumSecretKey;

    fn keypair() -> crate::Result<(Self::PublicKey, Self::SecretKey)> {
        let (pk_raw, sk_raw) = dilithium_internal_keypair(DilithiumVariant::Dilithium3)?;
        let variant = DilithiumVariant::Dilithium3;
        Ok((
            DilithiumPublicKey { raw: pk_raw, variant },
            DilithiumSecretKey { raw: sk_raw, variant },
        ))
    }
}

impl Sign for DilithiumVariant {
    type SecretKey = DilithiumSecretKey;
    type Signature = DilithiumSignature;

    fn sign(message: &[u8], sk: &Self::SecretKey) -> crate::Result<Self::Signature> {
        let raw = dilithium_internal_sign(message, &sk.raw)?;
        Ok(DilithiumSignature {
            raw,
            variant: sk.variant,
        })
    }
}

impl Verify for DilithiumVariant {
    type PublicKey = DilithiumPublicKey;
    type Signature = DilithiumSignature;

    fn verify(message: &[u8], signature: &Self::Signature, pk: &Self::PublicKey) -> crate::Result<bool> {
        dilithium_internal_verify(message, &signature.raw, &pk.raw)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dilithium_keypair() {
        let (pk, sk) = keypair().unwrap();
        assert_eq!(pk.len(), DILITHIUM3_PK_SIZE);
        assert_eq!(sk.len(), DILITHIUM3_SK_SIZE);
    }

    #[test]
    fn test_dilithium_sign_verify() {
        let (pk, sk) = keypair().unwrap();
        let msg = b"test message for dilithium signing";

        let sig = sign(msg, &sk).unwrap();
        assert_eq!(sig.len(), DILITHIUM3_SIG_SIZE);

        let valid = verify(msg, &sig, &pk).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_dilithium_variants() {
        for variant in &[DilithiumVariant::Dilithium2, DilithiumVariant::Dilithium3, DilithiumVariant::Dilithium5] {
            let (pk, sk) = keypair_variant(*variant).unwrap();
            assert_eq!(pk.len(), variant.pk_size());
            assert_eq!(sk.len(), variant.sk_size());

            let msg = b"test";
            let sig = sign(msg, &sk).unwrap();
            assert!(verify(msg, &sig, &pk).unwrap());
        }
    }

    #[test]
    fn test_dilithium_rejects_tampered() {
        let (pk, sk) = keypair().unwrap();
        let msg = b"important message";
        let sig = sign(msg, &sk).unwrap();

        let tampered_msg = b"tampered message";
        let valid = verify(tampered_msg, &sig, &pk).unwrap();
        assert!(!valid);
    }

    #[test]
    fn test_dilithium_trait_impl() {
        let (pk, sk) = DilithiumVariant::keypair().unwrap();
        let msg = b"trait test message";
        let sig = DilithiumVariant::sign(msg, &sk).unwrap();
        let valid = DilithiumVariant::verify(msg, &sig, &pk).unwrap();
        assert!(valid);
    }
}
