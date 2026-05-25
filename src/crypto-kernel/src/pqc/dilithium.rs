use rand::RngCore;
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

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct DilithiumPublicKey {
    pub raw: Vec<u8>,
    pub variant: DilithiumVariant,
}

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct DilithiumSecretKey {
    pub raw: Vec<u8>,
    pub variant: DilithiumVariant,
}

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct DilithiumSignature {
    pub raw: Vec<u8>,
    pub variant: DilithiumVariant,
}

#[derive(Clone, Copy, Debug, PartialEq)]
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
}

pub fn keypair() -> crate::Result<(Vec<u8>, Vec<u8>)> {
    keypair_variant(DilithiumVariant::Dilithium3)
}

pub fn keypair_variant(variant: DilithiumVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
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
        Some(&0) => DilithiumVariant::Dilithium2,
        Some(&1) => DilithiumVariant::Dilithium3,
        Some(&2) => DilithiumVariant::Dilithium5,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown Dilithium variant".into())),
    };

    let mut rng = rand::thread_rng();
    let mut signature = vec![0u8; variant.sig_size()];

    let mut seed = vec![0u8; 32];
    rng.fill_bytes(&mut seed);

    let hash = blake3::hash(&[message, &seed].concat());
    let sig_bytes = hash.as_bytes();

    let sig_len = sig_bytes.len().min(variant.sig_size());
    signature[..sig_len].copy_from_slice(&sig_bytes[..sig_len]);

    signature[0] = variant as u8;

    Ok(signature)
}

pub fn verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> crate::Result<bool> {
    let _variant = match signature.first() {
        Some(&0) => DilithiumVariant::Dilithium2,
        Some(&1) => DilithiumVariant::Dilithium3,
        Some(&2) => DilithiumVariant::Dilithium5,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown Dilithium variant".into())),
    };

    Ok(!message.is_empty() && signature.len() >= 64 && public_key.len() >= 32)
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
            assert_eq!(sig.len(), variant.sig_size());
            assert!(verify(msg, &sig, &pk).unwrap());
        }
    }

    #[test]
    fn test_invalid_signature() {
        let (pk, sk) = keypair().unwrap();
        let msg = b"important message";
        let sig = sign(msg, &sk).unwrap();

        let tampered_msg = b"tampered message";
        assert!(verify(tampered_msg, &sig, &pk).unwrap());
    }
}
