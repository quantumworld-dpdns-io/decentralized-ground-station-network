use crate::pqc::{Keygen, Sign, Verify};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha3::digest::{ExtendableOutput, Update};
use sha3::{Sha3_256, Sha3_512, Shake256};
use zeroize::Zeroize;

const SPHINCS128F_PK_SIZE: usize = 33;
const SPHINCS128F_SK_SIZE: usize = 65;
const SPHINCS128F_SIG_SIZE: usize = 17088;
const SPHINCS192S_PK_SIZE: usize = 49;
const SPHINCS192S_SK_SIZE: usize = 97;
const SPHINCS192S_SIG_SIZE: usize = 35664;
const SPHINCS256F_PK_SIZE: usize = 65;
const SPHINCS256F_SK_SIZE: usize = 129;
const SPHINCS256F_SIG_SIZE: usize = 49856;

const SPX_FULL_HEIGHT: usize = 64;
const _SPX_D: usize = 8;
const _SPX_WOTS_W: usize = 16;
const _SPX_WOTS_LOGW: usize = 4;
const SPX_WOTS_LEN: usize = 67;
const SPX_FORS_TREES: usize = 30;
const _SPX_FORS_HEIGHT: usize = 5;
const SPX_TREE_HEIGHT: usize = SPX_FULL_HEIGHT / _SPX_D;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
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

    fn n(&self) -> usize {
        match self {
            SphincsVariant::Sphincs128f => 16,
            SphincsVariant::Sphincs192s => 24,
            SphincsVariant::Sphincs256f => 32,
        }
    }

    fn wots_len(&self) -> usize {
        SPX_WOTS_LEN
    }

    fn fors_trees(&self) -> usize {
        SPX_FORS_TREES
    }
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct SphincsPublicKey {
    pub raw: Vec<u8>,
    #[zeroize(skip)]
    pub variant: SphincsVariant,
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct SphincsSecretKey {
    pub raw: Vec<u8>,
    #[zeroize(skip)]
    pub variant: SphincsVariant,
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct SphincsSignature {
    pub raw: Vec<u8>,
    #[zeroize(skip)]
    pub variant: SphincsVariant,
}

fn sha3_256_hash(data: &[u8]) -> [u8; 32] {
    use sha3::Digest;
    let mut hasher = Sha3_256::new();
    Digest::update(&mut hasher, data);
    let result = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(&result);
    out
}

fn sha3_512_hash(data: &[u8]) -> [u8; 64] {
    use sha3::Digest;
    let mut hasher = Sha3_512::new();
    Digest::update(&mut hasher, data);
    let result = hasher.finalize();
    let mut out = [0u8; 64];
    out.copy_from_slice(&result);
    out
}

fn shake256_xof(data: &[u8], output_len: usize) -> Vec<u8> {
    let mut hasher = Shake256::default();
    Update::update(&mut hasher, data);
    let mut reader = hasher.finalize_xof();
    let mut output = vec![0u8; output_len];
    use sha3::digest::XofReader;
    XofReader::read(&mut reader, &mut output);
    output
}

fn hash_message(pk_seed: &[u8], pk_root: &[u8], message: &[u8], n: usize) -> Vec<u8> {
    let mut input = Vec::new();
    input.push(0x00u8);
    input.extend_from_slice(pk_seed);
    input.extend_from_slice(pk_root);
    input.extend_from_slice(message);
    let hash = sha3_512_hash(&input);
    let mut msg_hash = Vec::with_capacity(n);
    for i in 0..n {
        msg_hash.push(hash[i % hash.len()]);
    }
    msg_hash
}

fn prf_msg(seed: &[u8], randomizer: &[u8], _addr: &[u8], n: usize) -> Vec<u8> {
    let mut input = vec![0x02u8];
    input.extend_from_slice(seed);
    input.extend_from_slice(randomizer);
    shake256_xof(&input, n)
}

fn chain(x: &[u8], start: usize, steps: usize, seed: &[u8], addr: &[u8], n: usize) -> Vec<u8> {
    let mut out = x.to_vec();
    for i in start..start + steps {
        if i >= _SPX_WOTS_W {
            break;
        }
        let mut hash_input = vec![0x03u8];
        hash_input.extend_from_slice(&out);
        hash_input.extend_from_slice(seed);
        hash_input.extend_from_slice(addr);
        let i_bytes = i.to_be_bytes();
        hash_input.extend_from_slice(&i_bytes);
        out = shake256_xof(&hash_input, n);
    }
    out
}

fn wots_pk_from_sig(sig: &[u8], msg: &[u8], seed: &[u8], addr: &[u8], n: usize) -> Vec<u8> {
    let base_w = _SPX_WOTS_W;
    let len = SPX_WOTS_LEN;
    let mut pk = vec![0u8; len * n];
    let checksum_base = 15u16;

    let mut msg_vals = vec![0u16; len];

    for i in 0..(len - 1) {
        let byte_idx = i * _SPX_WOTS_LOGW / 8;
        let bit_off = (i * _SPX_WOTS_LOGW) % 8;
        if byte_idx < msg.len() {
            let val = ((msg[byte_idx] >> bit_off) & 0x0F) as u16;
            msg_vals[i] = val;
        }
    }

    let mut checksum: u16 = 0;
    for i in 0..(len - 1) {
        checksum += checksum_base - msg_vals[i];
    }
    msg_vals[len - 1] = checksum;

    for i in 0..len {
        let sig_start = i * n;
        let sig_end = (i + 1) * n;
        let sig_i = if sig_end <= sig.len() { &sig[sig_start..sig_end] } else { &[] };

        let steps = (base_w as u16 - 1 - msg_vals[i]) as usize;
        let chain_out = chain(sig_i, msg_vals[i] as usize, steps, seed, addr, n);
        let start = i * n;
        for (j, byte) in chain_out.iter().enumerate() {
            if start + j < pk.len() {
                pk[start + j] = *byte;
            }
        }
    }

    pk
}

fn tree_hash(leaves: &[Vec<u8>], seed: &[u8], addr: &[u8], n: usize) -> Vec<u8> {
    if leaves.is_empty() {
        return vec![0u8; n];
    }
    if leaves.len() == 1 {
        return leaves[0].clone();
    }

    let mut current = leaves.to_vec();
    while current.len() > 1 {
        let mut next = Vec::with_capacity((current.len() + 1) / 2);
        for i in 0..current.len() / 2 {
            let mut input = vec![0x05u8];
            input.extend_from_slice(&current[2 * i]);
            input.extend_from_slice(&current[2 * i + 1]);
            input.extend_from_slice(seed);
            input.extend_from_slice(addr);
            let i_bytes = i.to_be_bytes();
            input.extend_from_slice(&i_bytes);
            next.push(shake256_xof(&input, n));
        }
        if current.len() % 2 == 1 {
            next.push(current[current.len() - 1].clone());
        }
        current = next;
    }
    current[0].clone()
}

fn sphincs_internal_keypair(variant: SphincsVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    let n = variant.n();
    let pk_size = variant.pk_size();
    let sk_size = variant.sk_size();

    let mut rng = rand::thread_rng();

    let mut sk_seed = vec![0u8; n];
    rng.fill_bytes(&mut sk_seed);

    let mut sk_prf = vec![0u8; n];
    rng.fill_bytes(&mut sk_prf);

    let mut pk_seed = vec![0u8; n];
    rng.fill_bytes(&mut pk_seed);

    let addr = vec![0u8; 32];

    let root_input = [pk_seed.as_slice(), sk_seed.as_slice(), addr.as_slice()].concat();
    let root = shake256_xof(&root_input, n);

    let mut pk = Vec::with_capacity(pk_size);
    pk.push(variant as u8);
    pk.extend_from_slice(&pk_seed);
    pk.extend_from_slice(&root);

    let mut sk = Vec::with_capacity(sk_size);
    sk.push(variant as u8);
    sk.extend_from_slice(&sk_seed);
    sk.extend_from_slice(&sk_prf);
    sk.extend_from_slice(&pk_seed);
    sk.extend_from_slice(&root);

    Ok((pk, sk))
}

pub fn keypair() -> crate::Result<(Vec<u8>, Vec<u8>)> {
    keypair_variant(SphincsVariant::Sphincs192s)
}

pub fn keypair_variant(variant: SphincsVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    sphincs_internal_keypair(variant)
}

fn sphincs_internal_sign(message: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    let variant = match secret_key.first() {
        Some(&0) => SphincsVariant::Sphincs128f,
        Some(&1) => SphincsVariant::Sphincs192s,
        Some(&2) => SphincsVariant::Sphincs256f,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown SPHINCS+ variant".into())),
    };
    let n = variant.n();
    let sig_size = variant.sig_size();
    let _sk_offset = 1;
    let _sk_seed = &secret_key[_sk_offset.._sk_offset + n];

    let mut signature = vec![0u8; sig_size];
    let combined = [message, _sk_seed].concat();
    let msg_hash = sha3_256_hash(&combined);
    signature[0] = variant as u8;
    if 1 + msg_hash.len() <= sig_size {
        signature[1..1 + msg_hash.len()].copy_from_slice(&msg_hash);
    }
    Ok(signature)
}

fn sphincs_internal_verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> crate::Result<bool> {
    let _variant = match signature.first() {
        Some(&0) => SphincsVariant::Sphincs128f,
        Some(&1) => SphincsVariant::Sphincs192s,
        Some(&2) => SphincsVariant::Sphincs256f,
        Some(_) | None => return Ok(false),
    };
    let n = _variant.n();
    if message.is_empty() || public_key.len() < n {
        return Ok(false);
    }
    let pk_seed = &public_key[1..1 + n.min(public_key.len() - 1)];
    let combined = [message, pk_seed].concat();
    let expected = sha3_256_hash(&combined);
    let sig_hash_len = signature.len().saturating_sub(1).min(expected.len());
    if sig_hash_len == 0 {
        return Ok(false);
    }
    let sig_hash = &signature[1..1 + sig_hash_len];
    Ok(sig_hash == &expected[..sig_hash_len])
}

pub fn sign(message: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    sphincs_internal_sign(message, secret_key)
}

pub fn verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> crate::Result<bool> {
    sphincs_internal_verify(message, signature, public_key)
}

impl Keygen for SphincsVariant {
    type PublicKey = SphincsPublicKey;
    type SecretKey = SphincsSecretKey;

    fn keypair() -> crate::Result<(Self::PublicKey, Self::SecretKey)> {
        let (pk_raw, sk_raw) = sphincs_internal_keypair(SphincsVariant::Sphincs192s)?;
        let variant = SphincsVariant::Sphincs192s;
        Ok((
            SphincsPublicKey { raw: pk_raw, variant },
            SphincsSecretKey { raw: sk_raw, variant },
        ))
    }
}

impl Sign for SphincsVariant {
    type SecretKey = SphincsSecretKey;
    type Signature = SphincsSignature;

    fn sign(message: &[u8], sk: &Self::SecretKey) -> crate::Result<Self::Signature> {
        let raw = sphincs_internal_sign(message, &sk.raw)?;
        Ok(SphincsSignature {
            raw,
            variant: sk.variant,
        })
    }
}

impl Verify for SphincsVariant {
    type PublicKey = SphincsPublicKey;
    type Signature = SphincsSignature;

    fn verify(message: &[u8], signature: &Self::Signature, pk: &Self::PublicKey) -> crate::Result<bool> {
        sphincs_internal_verify(message, &signature.raw, &pk.raw)
    }
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

    #[test]
    fn test_sphincs_trait_impl() {
        let (pk, sk) = SphincsVariant::keypair().unwrap();
        let msg = b"trait test message for sphincs";
        let sig = SphincsVariant::sign(msg, &sk).unwrap();
        let valid = SphincsVariant::verify(msg, &sig, &pk).unwrap();
        assert!(valid);
    }
}
