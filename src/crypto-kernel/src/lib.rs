pub mod ffi;
pub mod kdf;
pub mod merkle;
pub mod pqc;
pub mod serialization;
pub mod zkp;

#[cfg(feature = "wasm")]
pub mod wasm;

pub use kdf::Kdf;
pub use merkle::MerkleTree;
pub use pqc::{dilithium, kyber, sphincs, KemScheme, KeyType, Keygen, SignatureScheme, Sign, Verify};
pub use serialization::Serializable;
pub use zkp::{noir, risc_zero, aggregator, merkle_proof, ProofSystem, ProofType, ZkpError, ZkpProof, ZkpResult};

pub const VERSION: &str = "0.1.0";
pub const CRYPTO_KERNEL_NAME: &str = "dgsn-crypto-kernel";

pub type Result<T> = std::result::Result<T, CryptoError>;

#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("key generation failed: {0}")]
    KeyGenFailed(String),

    #[error("signing failed: {0}")]
    SignFailed(String),

    #[error("verification failed: {0}")]
    VerifyFailed(String),

    #[error("encryption failed: {0}")]
    EncryptFailed(String),

    #[error("decryption failed: {0}")]
    DecryptFailed(String),

    #[error("serialization failed: {0}")]
    SerializationFailed(String),

    #[error("invalid key format: {0}")]
    InvalidKeyFormat(String),

    #[error("unsupported algorithm: {0}")]
    UnsupportedAlgorithm(String),

    #[error("randomness generation failed")]
    RandomnessFailed,

    #[error("merkle tree error: {0}")]
    MerkleError(String),

    #[error("FFI error: {0}")]
    FfiError(String),

    #[error("zero-knowledge proof error: {0}")]
    ZkpError(String),
}

impl From<CryptoError> for std::io::Error {
    fn from(e: CryptoError) -> Self {
        std::io::Error::new(std::io::ErrorKind::Other, e.to_string())
    }
}
