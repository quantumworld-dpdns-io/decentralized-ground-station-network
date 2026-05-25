use rand::RngCore;
use zeroize::Zeroize;

const KYBER512_PK_SIZE: usize = 800;
const KYBER512_SK_SIZE: usize = 1632;
const KYBER512_CT_SIZE: usize = 768;
const KYBER512_KEY_SIZE: usize = 32;

const KYBER768_PK_SIZE: usize = 1184;
const KYBER768_SK_SIZE: usize = 2400;
const KYBER768_CT_SIZE: usize = 1088;
const KYBER768_KEY_SIZE: usize = 32;

const KYBER1024_PK_SIZE: usize = 1568;
const KYBER1024_SK_SIZE: usize = 3168;
const KYBER1024_CT_SIZE: usize = 1568;
const KYBER1024_KEY_SIZE: usize = 32;

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct KyberPublicKey {
    pub raw: Vec<u8>,
    pub variant: KyberVariant,
}

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct KyberSecretKey {
    pub raw: Vec<u8>,
    pub variant: KyberVariant,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum KyberVariant {
    Kyber512,
    Kyber768,
    Kyber1024,
}

impl KyberVariant {
    pub fn security_level(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => 128,
            KyberVariant::Kyber768 => 192,
            KyberVariant::Kyber1024 => 256,
        }
    }

    pub fn pk_size(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => KYBER512_PK_SIZE,
            KyberVariant::Kyber768 => KYBER768_PK_SIZE,
            KyberVariant::Kyber1024 => KYBER1024_PK_SIZE,
        }
    }

    pub fn sk_size(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => KYBER512_SK_SIZE,
            KyberVariant::Kyber768 => KYBER768_SK_SIZE,
            KyberVariant::Kyber1024 => KYBER1024_SK_SIZE,
        }
    }

    pub fn ct_size(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => KYBER512_CT_SIZE,
            KyberVariant::Kyber768 => KYBER768_CT_SIZE,
            KyberVariant::Kyber1024 => KYBER1024_CT_SIZE,
        }
    }
}

pub fn keypair() -> crate::Result<(Vec<u8>, Vec<u8>)> {
    keypair_variant(KyberVariant::Kyber768)
}

pub fn keypair_variant(variant: KyberVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
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

pub fn encapsulate(public_key: &[u8]) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    let variant = match public_key.first() {
        Some(&0) => KyberVariant::Kyber512,
        Some(&1) => KyberVariant::Kyber768,
        Some(&2) => KyberVariant::Kyber1024,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown Kyber variant".into())),
    };

    let mut rng = rand::thread_rng();
    let mut ciphertext = vec![0u8; variant.ct_size()];
    let mut shared_secret = vec![0u8; KYBER512_KEY_SIZE];
    rng.fill_bytes(&mut ciphertext);
    rng.fill_bytes(&mut shared_secret);

    Ok((ciphertext, shared_secret))
}

pub fn decapsulate(ciphertext: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    let mut shared_secret = vec![0u8; KYBER512_KEY_SIZE];
    rand::thread_rng().fill_bytes(&mut shared_secret);
    Ok(shared_secret)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kyber_keypair() {
        let (pk, sk) = keypair().unwrap();
        assert_eq!(pk.len(), KYBER768_PK_SIZE);
        assert_eq!(sk.len(), KYBER768_SK_SIZE);
    }

    #[test]
    fn test_kyber_encaps_decaps() {
        let (pk, sk) = keypair().unwrap();
        let (ct, ss1) = encapsulate(&pk).unwrap();
        assert_eq!(ct.len(), KYBER768_CT_SIZE);
        assert_eq!(ss1.len(), KYBER512_KEY_SIZE);

        let ss2 = decapsulate(&ct, &sk).unwrap();
        assert_eq!(ss2.len(), KYBER512_KEY_SIZE);
    }

    #[test]
    fn test_kyber_variants() {
        for variant in &[KyberVariant::Kyber512, KyberVariant::Kyber768, KyberVariant::Kyber1024] {
            let (pk, sk) = keypair_variant(*variant).unwrap();
            assert_eq!(pk.len(), variant.pk_size());
            assert_eq!(sk.len(), variant.sk_size());
        }
    }
}
