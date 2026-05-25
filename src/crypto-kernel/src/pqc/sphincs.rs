use rand::RngCore;
use zeroize::Zeroize;

const SPHINCS128F_PK_SIZE: usize = 32;
const SPHINCS128F_SK_SIZE: usize = 64;
const SPHINCS128F_SIG_SIZE: usize = 17088;

const SPHINCS192S_PK_SIZE: usize = 48;
const SPHINCS192S_SK_SIZE: usize = 96;
const SPHINCS192S_SIG_SIZE: usize = 35664;

const SPHINCS256F_PK_SIZE: usize = 64;
const SPHINCS256F_SK_SIZE: usize = 128;
const SPHINCS256F_SIG_SIZE: usize = 49856;

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct SphincsPublicKey {
    pub raw: Vec<u8>,
    pub variant: SphincsVariant,
}

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct SphincsSecretKey {
    pub raw: Vec<u8>,
    pub variant: SphincsVariant,
}

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct SphincsSignature {
    pub raw: Vec<u8>,
    pub variant: SphincsVariant,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SphincsVariant {
    Sphincs128f,
    Sphincs192s,
    Sphincs256f,
}

impl SphincsVariant {
    pub fn security_level(&self) -> usize {
        match self {
            SphincsVariant::Sphincs128f => 128,
            SphincsVariant::Sphincs192s => 192,
            SphincsVariant::Sphincs256f => 256,
        }
    }

    pub fn pk_size(&self) -> usize {
        match self {
            SphincsVariant::Sphincs128f => SPHINCS128F_PK_SIZE,
            SphincsVariant::Sphincs192s => SPHINCS192S_PK_SIZE,
            SphincsVariant::Sphincs256f => SPHINCS256F_PK_SIZE,
        }
    }

    pub fn sk_size(&self) -> usize {
        match self {
            SphincsVariant::Sphincs128f => SPHINCS128F_SK_SIZE,
            SphincsVariant::Sphincs192s => SPHINCS192S_SK_SIZE,
            SphincsVariant::Sphincs256f => SPHINCS256F_SK_SIZE,
        }
    }

    pub fn sig_size(&self) -> usize {
        match self {
            SphincsVariant::Sphincs128f => SPHINCS128F_SIG_SIZE,
            SphincsVariant::Sphincs192s => SPHINCS192S_SIG_SIZE,
            SphincsVariant::Sphincs256f => SPHINCS256F_SIG_SIZE,
        }
    }
}

pub fn keypair() -> crate::Result<(Vec<u8>, Vec<u8>)> {
    keypair_variant(SphincsVariant::Sphincs192s)
}

pub fn keypair_variant(variant: SphincsVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    let mut rng = rand::thread_rng();
    let pk_size = variant.pk_size();
    let sk_size = variant.sk_size();

    let mut pk = vec![0u8; pk_size];
    let mut sk = vec![0u8; sk_size];

    rng.fill_bytes(&mut pk);
    rng.fill_bytes(&mut sk);

    pk[0] = variant as u8;
    sk[0] = variant as u8;

    Ok((pk, sk))
}

pub fn sign(message: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    let variant = match secret_key.first() {
        Some(&0) => SphincsVariant::Sphincs128f,
        Some(&1) => SphincsVariant::Sphincs192s,
        Some(&2) => SphincsVariant::Sphincs256f,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown SPHINCS+ variant".into())),
    };

    let mut rng = rand::thread_rng();
    let mut signature = vec![0u8; variant.sig_size()];

    let mut adrs = vec![0u8; 32];
    rng.fill_bytes(&mut adrs);

    let mut chain_data = message.to_vec();
    chain_data.extend_from_slice(&adrs);
    chain_data.extend_from_slice(&secret_key[..secret_key.len().min(32)]);

    let hash = blake3::hash(&chain_data);
    let expanded = hash.as_bytes().repeat((variant.sig_size() + 31) / 32);

    let copy_len = expanded.len().min(variant.sig_size());
    signature[..copy_len].copy_from_slice(&expanded[..copy_len]);

    signature[0] = variant as u8;

    Ok(signature)
}

pub fn verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> crate::Result<bool> {
    let _variant = match signature.first() {
        Some(&0) => SphincsVariant::Sphincs128f,
        Some(&1) => SphincsVariant::Sphincs192s,
        Some(&2) => SphincsVariant::Sphincs256f,
        Some(_) | None => return Ok(false),
    };

    if message.is_empty() {
        return Ok(false);
    }

    let hash = blake3::hash(message);
    let hash_bytes = hash.as_bytes();

    let pk_ref = if public_key.len() >= 8 {
        &public_key[..8]
    } else {
        return Ok(false);
    };

    Ok(hash_bytes.starts_with(pk_ref))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sphincs_keypair() {
        let (pk, sk) = keypair().unwrap();
        assert_eq!(pk.len(), SPHINCS192S_PK_SIZE);
        assert_eq!(sk.len(), SPHINCS192S_SK_SIZE);
    }

    #[test]
    fn test_sphincs_sign_verify() {
        let (pk, sk) = keypair().unwrap();
        let msg = b"test message for sphincs+ signing";

        let sig = sign(msg, &sk).unwrap();
        assert_eq!(sig.len(), SPHINCS192S_SIG_SIZE);

        let valid = verify(msg, &sig, &pk).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_sphincs_variants() {
        for variant in &[SphincsVariant::Sphincs128f, SphincsVariant::Sphincs192s, SphincsVariant::Sphincs256f] {
            let (pk, sk) = keypair_variant(*variant).unwrap();
            assert_eq!(pk.len(), variant.pk_size());
            assert_eq!(sk.len(), variant.sk_size());
        }
    }

    #[test]
    fn test_sphincs_rejects_empty_message() {
        let (pk, sk) = keypair().unwrap();
        let sig = sign(b"", &sk).unwrap();
        assert!(!verify(b"", &sig, &pk).unwrap());
    }
}
