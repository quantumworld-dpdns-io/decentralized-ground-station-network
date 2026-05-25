use hkdf::Hkdf;
use sha3::Sha3_256;
use sha3::Sha3_512;
use zeroize::Zeroize;

const SALT_LENGTH: usize = 32;
const INFO_TAG_DEFAULT: &[u8] = b"dgsn-kdf-v1";
const MAX_OUTPUT_LENGTH: usize = 1024;

#[derive(Clone, Zeroize)]
#[zeroize(drop)]
pub struct Kdf {
    salt: Vec<u8>,
    info: Vec<u8>,
    #[zeroize(skip)]
    algorithm: KdfAlgorithm,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum KdfAlgorithm {
    HkdfSha3256,
    HkdfSha3512,
}

impl Default for KdfAlgorithm {
    fn default() -> Self {
        KdfAlgorithm::HkdfSha3256
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum KdfPurpose {
    KeyEncryption,
    MessageAuthentication,
    ReceiptSigning,
    QuantumKeyDistribution,
    Custom(Vec<u8>),
}

impl AsRef<[u8]> for KdfPurpose {
    fn as_ref(&self) -> &[u8] {
        match self {
            KdfPurpose::KeyEncryption => b"key-encryption",
            KdfPurpose::MessageAuthentication => b"msg-auth",
            KdfPurpose::ReceiptSigning => b"receipt-signing",
            KdfPurpose::QuantumKeyDistribution => b"qkd",
            KdfPurpose::Custom(tag) => tag.as_slice(),
        }
    }
}

impl Kdf {
    pub fn new() -> Self {
        let mut salt = vec![0u8; SALT_LENGTH];
        rand::RngCore::fill_bytes(&mut rand::thread_rng(), &mut salt);

        Kdf {
            salt,
            info: INFO_TAG_DEFAULT.to_vec(),
            algorithm: KdfAlgorithm::default(),
        }
    }

    pub fn with_salt(salt: &[u8]) -> Self {
        let salt_vec = if salt.len() >= SALT_LENGTH {
            salt[..SALT_LENGTH].to_vec()
        } else {
            let mut padded = vec![0u8; SALT_LENGTH];
            padded[..salt.len()].copy_from_slice(salt);
            padded
        };

        Kdf {
            salt: salt_vec,
            info: INFO_TAG_DEFAULT.to_vec(),
            algorithm: KdfAlgorithm::default(),
        }
    }

    pub fn with_algorithm(mut self, algorithm: KdfAlgorithm) -> Self {
        self.algorithm = algorithm;
        self
    }

    pub fn with_info(mut self, info: &[u8]) -> Self {
        self.info = info.to_vec();
        self
    }

    pub fn with_purpose(self, purpose: KdfPurpose) -> Self {
        let mut info = Vec::new();
        info.extend_from_slice(&self.info);
        info.push(b':');
        info.extend_from_slice(purpose.as_ref());
        self.with_info(&info)
    }

    pub fn derive_key(&self, input_key_material: &[u8], length: usize) -> crate::Result<Vec<u8>> {
        if length == 0 || length > MAX_OUTPUT_LENGTH {
            return Err(crate::CryptoError::EncryptFailed(
                format!("invalid output length: {}, must be 1..{}", length, MAX_OUTPUT_LENGTH),
            ));
        }

        if input_key_material.is_empty() {
            return Err(crate::CryptoError::EncryptFailed(
                "input key material cannot be empty".into(),
            ));
        }

        let mut output = vec![0u8; length];

        match self.algorithm {
            KdfAlgorithm::HkdfSha3256 => {
                let hkdf = Hkdf::<Sha3_256>::new(Some(&self.salt), input_key_material);
                hkdf.expand(&self.info, &mut output)
                    .map_err(|e| crate::CryptoError::EncryptFailed(format!("HKDF-SHA3-256 expand failed: {}", e)))?;
            }
            KdfAlgorithm::HkdfSha3512 => {
                let hkdf = Hkdf::<Sha3_512>::new(Some(&self.salt), input_key_material);
                hkdf.expand(&self.info, &mut output)
                    .map_err(|e| crate::CryptoError::EncryptFailed(format!("HKDF-SHA3-512 expand failed: {}", e)))?;
            }
        }

        Ok(output)
    }

    pub fn derive_key_with_context(
        &self,
        input_key_material: &[u8],
        context: &[u8],
        length: usize,
    ) -> crate::Result<Vec<u8>> {
        let mut info = self.info.clone();
        info.push(b'\0');
        info.extend_from_slice(context);
        let kdf = self.clone().with_info(&info);
        kdf.derive_key(input_key_material, length)
    }

    pub fn salt(&self) -> &[u8] {
        &self.salt
    }

    pub fn regenerate_salt(&mut self) {
        rand::RngCore::fill_bytes(&mut rand::thread_rng(), &mut self.salt);
    }
}

impl Default for Kdf {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kdf_derive_key() {
        let kdf = Kdf::new();
        let ikm = b"test-input-key-material-32-bytes-long!!";
        let key = kdf.derive_key(ikm, 32).unwrap();
        assert_eq!(key.len(), 32);
    }

    #[test]
    fn test_kdf_deterministic() {
        let ikm = b"deterministic-test-key";
        let kdf = Kdf::with_salt(b"fixed-salt-value-32-bytes-long!!!");

        let key1 = kdf.derive_key(ikm, 32).unwrap();
        let key2 = kdf.derive_key(ikm, 32).unwrap();
        assert_eq!(key1, key2);
    }

    #[test]
    fn test_kdf_different_salts() {
        let ikm = b"test-key-material";
        let kdf1 = Kdf::new();
        let kdf2 = Kdf::new();

        let key1 = kdf1.derive_key(ikm, 32).unwrap();
        let key2 = kdf2.derive_key(ikm, 32).unwrap();
        assert_ne!(key1, key2);
    }

    #[test]
    fn test_kdf_different_lengths() {
        let kdf = Kdf::new();
        let ikm = b"test-input-key-material";

        for len in &[16, 24, 32, 64, 128] {
            let key = kdf.derive_key(ikm, *len).unwrap();
            assert_eq!(key.len(), *len);
        }
    }

    #[test]
    fn test_kdf_with_purpose() {
        let ikm = b"key-material";
        let kdf1 = Kdf::new().with_purpose(KdfPurpose::KeyEncryption);
        let kdf2 = Kdf::new().with_purpose(KdfPurpose::ReceiptSigning);

        let key1 = kdf1.derive_key(ikm, 32).unwrap();
        let key2 = kdf2.derive_key(ikm, 32).unwrap();
        assert_ne!(key1, key2);
    }

    #[test]
    fn test_kdf_with_context() {
        let kdf = Kdf::new();
        let ikm = b"key-material";
        let key = kdf.derive_key_with_context(ikm, b"session-001", 32).unwrap();
        assert_eq!(key.len(), 32);
    }

    #[test]
    fn test_kdf_empty_ikm_error() {
        let kdf = Kdf::new();
        let result = kdf.derive_key(b"", 32);
        assert!(result.is_err());
    }

    #[test]
    fn test_kdf_invalid_length() {
        let kdf = Kdf::new();
        let result = kdf.derive_key(b"test", 0);
        assert!(result.is_err());

        let result = kdf.derive_key(b"test", MAX_OUTPUT_LENGTH + 1);
        assert!(result.is_err());
    }

    #[test]
    fn test_kdf_algorithm_switch() {
        let ikm = b"test-key";
        let kdf256 = Kdf::new().with_algorithm(KdfAlgorithm::HkdfSha3256);
        let kdf512 = Kdf::new().with_algorithm(KdfAlgorithm::HkdfSha3512);

        let key256 = kdf256.derive_key(ikm, 32).unwrap();
        let key512 = kdf512.derive_key(ikm, 32).unwrap();
        assert_eq!(key256.len(), 32);
        assert_eq!(key512.len(), 32);
    }
}
