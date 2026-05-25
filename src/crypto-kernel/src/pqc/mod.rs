pub mod dilithium;
pub mod kyber;
pub mod sphincs;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum KeyType {
    Signing,
    Encryption,
    Kem,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Algorithm {
    MLKEM512,
    MLKEM768,
    MLKEM1024,
    MLDSA44,
    MLDSA65,
    MLDSA87,
    SLHDSA128F,
    SLHDSA192S,
    SLHDSA256F,
}

impl Algorithm {
    pub fn name(&self) -> &'static str {
        match self {
            Algorithm::MLKEM512 => "ML-KEM-512",
            Algorithm::MLKEM768 => "ML-KEM-768",
            Algorithm::MLKEM1024 => "ML-KEM-1024",
            Algorithm::MLDSA44 => "ML-DSA-44",
            Algorithm::MLDSA65 => "ML-DSA-65",
            Algorithm::MLDSA87 => "ML-DSA-87",
            Algorithm::SLHDSA128F => "SLH-DSA-128f",
            Algorithm::SLHDSA192S => "SLH-DSA-192s",
            Algorithm::SLHDSA256F => "SLH-DSA-256f",
        }
    }

    pub fn security_level(&self) -> usize {
        match self {
            Algorithm::MLKEM512 | Algorithm::MLDSA44 | Algorithm::SLHDSA128F => 128,
            Algorithm::MLKEM768 | Algorithm::MLDSA65 | Algorithm::SLHDSA192S => 192,
            Algorithm::MLKEM1024 | Algorithm::MLDSA87 | Algorithm::SLHDSA256F => 256,
        }
    }

    pub fn key_type(&self) -> KeyType {
        match self {
            Algorithm::MLKEM512 | Algorithm::MLKEM768 | Algorithm::MLKEM1024 => KeyType::Kem,
            Algorithm::MLDSA44 | Algorithm::MLDSA65 | Algorithm::MLDSA87 => KeyType::Signing,
            Algorithm::SLHDSA128F | Algorithm::SLHDSA192S | Algorithm::SLHDSA256F => KeyType::Signing,
        }
    }
}

pub trait Keygen {
    type PublicKey;
    type SecretKey;

    fn keypair() -> crate::Result<(Self::PublicKey, Self::SecretKey)>;
}

pub trait Sign {
    type SecretKey;
    type Signature;

    fn sign(message: &[u8], sk: &Self::SecretKey) -> crate::Result<Self::Signature>;
}

pub trait Verify {
    type PublicKey;
    type Signature;

    fn verify(message: &[u8], signature: &Self::Signature, pk: &Self::PublicKey) -> crate::Result<bool>;
}

pub trait SignatureScheme: Keygen + Sign + Verify {}

pub trait KemScheme {
    type PublicKey;
    type SecretKey;
    type Ciphertext;

    fn keygen() -> crate::Result<(Self::PublicKey, Self::SecretKey)>;

    fn encapsulate(pk: &Self::PublicKey) -> crate::Result<(Self::Ciphertext, Vec<u8>)>;

    fn decapsulate(ct: &Self::Ciphertext, sk: &Self::SecretKey) -> crate::Result<Vec<u8>>;
}

pub fn keygen(algorithm: Algorithm) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    match algorithm {
        Algorithm::MLKEM512 | Algorithm::MLKEM768 | Algorithm::MLKEM1024 => {
            kyber::keypair()
        }
        Algorithm::MLDSA44 | Algorithm::MLDSA65 | Algorithm::MLDSA87 => {
            dilithium::keypair()
        }
        Algorithm::SLHDSA128F | Algorithm::SLHDSA192S | Algorithm::SLHDSA256F => {
            sphincs::keypair()
        }
    }
}

pub fn sign(algorithm: &Algorithm, message: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    match algorithm {
        Algorithm::MLDSA44 | Algorithm::MLDSA65 | Algorithm::MLDSA87 => {
            dilithium::sign(message, secret_key)
        }
        Algorithm::SLHDSA128F | Algorithm::SLHDSA192S | Algorithm::SLHDSA256F => {
            sphincs::sign(message, secret_key)
        }
        _ => Err(crate::CryptoError::UnsupportedAlgorithm(
            format!("{} does not support signing", algorithm.name()),
        )),
    }
}

pub fn verify(
    algorithm: &Algorithm,
    message: &[u8],
    signature: &[u8],
    public_key: &[u8],
) -> crate::Result<bool> {
    match algorithm {
        Algorithm::MLDSA44 | Algorithm::MLDSA65 | Algorithm::MLDSA87 => {
            dilithium::verify(message, signature, public_key)
        }
        Algorithm::SLHDSA128F | Algorithm::SLHDSA192S | Algorithm::SLHDSA256F => {
            sphincs::verify(message, signature, public_key)
        }
        _ => Err(crate::CryptoError::UnsupportedAlgorithm(
            format!("{} does not support signature verification", algorithm.name()),
        )),
    }
}
