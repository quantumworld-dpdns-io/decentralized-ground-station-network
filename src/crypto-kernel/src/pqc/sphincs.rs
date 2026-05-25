use crate::pqc::{Keygen, Sign, Verify};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha3::digest::{ExtendableOutput, Update};
use sha3::{Sha3_256, Sha3_512, Shake256};
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

const SPX_FULL_HEIGHT: usize = 64;
const SPX_D: usize = 8;
const SPX_WOTS_W: usize = 16;
const SPX_WOTS_LOGW: usize = 4;
const SPX_WOTS_LEN: usize = 67;
const SPX_FORS_TREES: usize = 30;
const SPX_FORS_HEIGHT: usize = 5;
const SPX_TREE_HEIGHT: usize = SPX_FULL_HEIGHT / SPX_D;

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

    fn fors_height(&self) -> usize {
        SPX_FORS_HEIGHT
    }

    fn d(&self) -> usize {
        SPX_D
    }

    fn tree_height(&self) -> usize {
        SPX_TREE_HEIGHT
    }
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct SphincsPublicKey {
    pub raw: Vec<u8>,
    pub variant: SphincsVariant,
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct SphincsSecretKey {
    pub raw: Vec<u8>,
    pub variant: SphincsVariant,
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct SphincsSignature {
    pub raw: Vec<u8>,
    pub variant: SphincsVariant,
}

fn sha3_256_hash(data: &[u8]) -> [u8; 32] {
    use sha3::Digest;
    let mut hasher = Sha3_256::new();
    hasher.update(data);
    let result = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(&result);
    out
}

fn sha3_512_hash(data: &[u8]) -> [u8; 64] {
    use sha3::Digest;
    let mut hasher = Sha3_512::new();
    hasher.update(data);
    let result = hasher.finalize();
    let mut out = [0u8; 64];
    out.copy_from_slice(&result);
    out
}

fn shake256_xof(data: &[u8], output_len: usize) -> Vec<u8> {
    let mut hasher = Shake256::default();
    hasher.update(data);
    let mut output = vec![0u8; output_len];
    hasher.squeeze(&mut output);
    output
}

fn mgf1(seed: &[u8], mask_len: usize) -> Vec<u8> {
    let mut mask = Vec::with_capacity(mask_len);
    let mut counter = 0u32;
    while mask.len() < mask_len {
        let mut input = seed.to_vec();
        input.extend_from_slice(&counter.to_be_bytes());
        let hash = sha3_256_hash(&input);
        mask.extend_from_slice(&hash);
        counter += 1;
    }
    mask.truncate(mask_len);
    mask
}

fn hash_message(pk_seed: &[u8], pk_root: &[u8], message: &[u8], n: usize) -> Vec<u8> {
    let mut input = Vec::new();
    input.push(0x00u8);
    input.extend_from_slice(pk_seed);
    input.extend_from_slice(pk_root);
    input.extend_from_slice(message);
    let mut hash = sha3_512_hash(&input);
    hash.truncate(n * (1 + SPX_FORS_TREES));
    hash
}

fn prf_addr(seed: &[u8], addr: &[u8], n: usize) -> Vec<u8> {
    let mut input = vec![0x01u8];
    input.extend_from_slice(seed);
    input.extend_from_slice(addr);
    shake256_xof(&input, n)
}

fn prf_msg(seed: &[u8], randomizer: &[u8], addr: &[u8], n: usize) -> Vec<u8> {
    let mut input = vec![0x02u8];
    input.extend_from_slice(seed);
    input.extend_from_slice(randomizer);
    input.extend_from_slice(addr);
    shake256_xof(&input, n)
}

fn chain(x: &[u8], start: usize, steps: usize, seed: &[u8], addr: &[u8], n: usize) -> Vec<u8> {
    let mut out = x.to_vec();
    for i in start..start + steps {
        if i >= SPX_WOTS_W {
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
    let base_w = SPX_WOTS_W;
    let len = SPX_WOTS_LEN;
    let mut pk = Vec::with_capacity(len * n);
    let checksum_base = 15u16;

    let mut msg_vals = Vec::with_capacity(len);
    for i in 0..len {
        msg_vals.push(0u16);
    }

    for i in 0..(len - 1) {
        let byte_idx = i * SPX_WOTS_LOGW / 8;
        let bit_off = (i * SPX_WOTS_LOGW) % 8;
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

fn wots_gen_leaf(seed: &[u8], leaf_idx: usize, addr: &[u8], n: usize) -> Vec<u8> {
    let mut chain_input = vec![0x04u8];
    chain_input.extend_from_slice(seed);
    chain_input.extend_from_slice(addr);
    let leaf_idx_bytes = leaf_idx.to_be_bytes();
    chain_input.extend_from_slice(&leaf_idx_bytes);
    shake256_xof(&chain_input, n)
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

    let root_input = [&pk_seed, &sk_seed, &addr].concat();
    let root = shake256_xof(&root_input, n);

    let mut pk = Vec::with_capacity(pk_size);
    pk.extend_from_slice(&pk_seed);
    pk.extend_from_slice(&root);

    let mut sk = Vec::with_capacity(sk_size);
    sk.extend_from_slice(&sk_seed);
    sk.extend_from_slice(&sk_prf);
    sk.extend_from_slice(&pk_seed);
    sk.extend_from_slice(&root);

    pk[0] = variant as u8;
    sk[0] = variant as u8;

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
    let wots_len = variant.wots_len();
    let fors_trees = variant.fors_trees();
    let fors_height = variant.fors_height();
    let d = variant.d();
    let tree_height = variant.tree_height();

    let sk_offset = 1;
    let sk_seed = &secret_key[sk_offset..sk_offset + n];
    let sk_prf = &secret_key[sk_offset + n..sk_offset + 2 * n];
    let pk_seed = &secret_key[sk_offset + 2 * n..sk_offset + 3 * n];
    let pk_root = &secret_key[sk_offset + 3 * n..sk_offset + 4 * n];

    let mut rng = rand::thread_rng();
    let mut opt_rand = vec![0u8; n];
    rng.fill_bytes(&mut opt_rand);

    let msg_hash = hash_message(pk_seed, pk_root, message, n);

    let r = prf_msg(sk_seed, &opt_rand, &[], n);

    let fors_msg_offset = n;
    let fors_msg = &msg_hash[fors_msg_offset..];

    let mut signature = Vec::with_capacity(sig_size);
    signature.push(variant as u8);

    signature.extend_from_slice(&r);

    let addr = vec![0u8; 32];

    let fors_sig_size = fors_trees * (1 + fors_height) * n;
    let mut fors_sig = Vec::with_capacity(fors_sig_size);
    for i in 0..fors_trees {
        let leaf_start = i * fors_height * n / 8;
        let leaf_end = ((i + 1) * fors_height * n + 7) / 8;
        let leaf_data = if fors_msg.len() > leaf_start {
            let end = leaf_end.min(fors_msg.len());
            fors_msg[leaf_start..end].to_vec()
        } else {
            vec![0u8; fors_height * n / 8]
        };
        fors_sig.extend_from_slice(&shake256_xof(&leaf_data, n));
    }
    signature.extend_from_slice(&fors_sig);

    for i in 0..d {
        let tree_addr = {
            let mut a = vec![0u8; 32];
            let i_bytes = (i as u32).to_be_bytes();
            a[..4].copy_from_slice(&i_bytes);
            a
        };
        let wots_sig = (0..wots_len).flat_map(|_| {
            let val = shake256_xof(&[pk_seed, &tree_addr].concat(), n);
            val
        }).collect::<Vec<_>>();
        signature.extend_from_slice(&wots_sig);

        let wots_pk = wots_pk_from_sig(&wots_sig, &[], pk_seed, &tree_addr, n);
        let leaf_hash = wots_pk;

        let mut auth_path = Vec::new();
        for j in 0..tree_height {
            let sibling = shake256_xof(&[pk_seed, &tree_addr, &j.to_be_bytes()].concat(), n);
            auth_path.extend_from_slice(&sibling);
        }
        signature.extend_from_slice(&auth_path);
    }

    if signature.len() > sig_size {
        signature.truncate(sig_size);
    } else {
        let pad = sig_size - signature.len();
        signature.extend(std::iter::repeat(0u8).take(pad));
    }

    Ok(signature)
}

pub fn sign(message: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    sphincs_internal_sign(message, secret_key)
}

fn sphincs_internal_verify(message: &[u8], signature: &[u8], public_key: &[u8]) -> crate::Result<bool> {
    let _variant = match signature.first() {
        Some(&0) => SphincsVariant::Sphincs128f,
        Some(&1) => SphincsVariant::Sphincs192s,
        Some(&2) => SphincsVariant::Sphincs256f,
        Some(_) | None => return Ok(false),
    };

    if message.is_empty() || public_key.len() < 8 {
        return Ok(false);
    }

    let sig_data = &signature[1..];
    if sig_data.len() < 32 {
        return Ok(false);
    }

    let pk_seed = &public_key[1..];
    let n = match signature.first() {
        Some(&0) => 16usize,
        Some(&1) => 24usize,
        Some(&2) => 32usize,
        _ => 16usize,
    };

    if pk_seed.len() < n {
        return Ok(false);
    }
    let pk_root = &pk_seed[n..];
    if pk_root.len() < n {
        return Ok(false);
    }

    let msg_hash = hash_message(&pk_seed[..n], &pk_root[..n], message, n);

    let r = &sig_data[..n.min(sig_data.len())];

    let fors_sig_offset = n;
    let fors_trees = SPX_FORS_TREES;
    let fors_height = SPX_FORS_HEIGHT;
    let fors_sig_size = fors_trees * (1 + fors_height) * n;

    let fors_sig_end = (fors_sig_offset + fors_sig_size).min(sig_data.len());

    let fors_msg_offset = n;
    let fors_msg = &msg_hash[fors_msg_offset..];

    let mut leaf_nodes = Vec::new();
    for i in 0..fors_trees {
        let leaf_start = i * fors_height * n / 8;
        let leaf_end = ((i + 1) * fors_height * n + 7) / 8;
        let leaf_data = if fors_msg.len() > leaf_start {
            let end = leaf_end.min(fors_msg.len());
            &fors_msg[leaf_start..end]
        } else {
            &[]
        };
        let hash = shake256_xof(leaf_data, n);
        leaf_nodes.push(hash);
    }

    let computed_root = tree_hash(&leaf_nodes, &pk_seed[..n], &[], n);

    let d = SPX_D;
    let tree_height = SPX_TREE_HEIGHT;
    let wots_len = SPX_WOTS_LEN;

    let mut sig_offset = fors_sig_end;
    let mut expected_root = computed_root;

    for _layer in 0..d {
        if sig_offset + wots_len * n > sig_data.len() {
            return Ok(false);
        }
        let wots_sig = &sig_data[sig_offset..sig_offset + wots_len * n];
        sig_offset += wots_len * n;

        if sig_offset + tree_height * n > sig_data.len() {
            return Ok(false);
        }
        sig_offset += tree_height * n;

        let addr = vec![0u8; 32];
        let wots_pk = wots_pk_from_sig(wots_sig, &[], &pk_seed[..n], &addr, n);
        let leaf_hash = tree_hash(&[wots_pk], &pk_seed[..n], &addr, n);

        let mut current = leaf_hash;
        for _j in 0..tree_height {
            current = shake256_xof(&[&current, &pk_seed[..n]].concat(), n);
        }
        expected_root = current;
    }

    let pk_root_from_sig = &expected_root;

    let hash_check = if pk_root.len() >= pk_root_from_sig.len() {
        &pk_root[..pk_root_from_sig.len()] == pk_root_from_sig.as_slice()
    } else {
        false
    };

    Ok(hash_check)
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
