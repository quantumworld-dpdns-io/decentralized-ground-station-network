use crate::merkle::{MerkleProof, MerkleTree};
use crate::pqc::{self, Algorithm};
use crate::zkp::{noir::NoirBackend, ProofSystem, ProofType, ZkpProof};
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct WasmCrypto;

#[wasm_bindgen]
impl WasmCrypto {
    pub fn new() -> Self {
        WasmCrypto
    }

    pub fn keygen(algorithm_name: &str) -> Result<JsValue, JsValue> {
        let algorithm = parse_algorithm(algorithm_name)?;
        let (pk, sk) = pqc::keygen(algorithm)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let result = js_sys::Object::new();
        js_sys::Reflect::set(&result, &JsValue::from_str("publicKey"), &js_sys::Uint8Array::from(&pk[..]))
            .map_err(|_| JsValue::from_str("failed to set publicKey"))?;
        js_sys::Reflect::set(&result, &JsValue::from_str("secretKey"), &js_sys::Uint8Array::from(&sk[..]))
            .map_err(|_| JsValue::from_str("failed to set secretKey"))?;
        Ok(JsValue::from(result))
    }

    pub fn sign(algorithm_name: &str, message: &[u8], secret_key: &[u8]) -> Result<js_sys::Uint8Array, JsValue> {
        let algorithm = parse_sign_algorithm(algorithm_name)?;
        let sig = pqc::sign(&algorithm, message, secret_key)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        Ok(js_sys::Uint8Array::from(&sig[..]))
    }

    pub fn verify(
        algorithm_name: &str,
        message: &[u8],
        signature: &[u8],
        public_key: &[u8],
    ) -> Result<bool, JsValue> {
        let algorithm = parse_sign_algorithm(algorithm_name)?;
        pqc::verify(&algorithm, message, signature, public_key)
            .map_err(|e| JsValue::from_str(&e.to_string()))
    }

    pub fn kem_encapsulate(public_key: &[u8]) -> Result<JsValue, JsValue> {
        let (ct, ss) = crate::pqc::kyber::encapsulate(public_key)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let result = js_sys::Object::new();
        js_sys::Reflect::set(&result, &JsValue::from_str("ciphertext"), &js_sys::Uint8Array::from(&ct[..]))
            .map_err(|_| JsValue::from_str("failed to set ciphertext"))?;
        js_sys::Reflect::set(&result, &JsValue::from_str("sharedSecret"), &js_sys::Uint8Array::from(&ss[..]))
            .map_err(|_| JsValue::from_str("failed to set sharedSecret"))?;
        Ok(JsValue::from(result))
    }

    pub fn kem_decapsulate(ciphertext: &[u8], secret_key: &[u8]) -> Result<js_sys::Uint8Array, JsValue> {
        let ss = crate::pqc::kyber::decapsulate(ciphertext, secret_key)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        Ok(js_sys::Uint8Array::from(&ss[..]))
    }

    pub fn receipt_verify(
        receipt_data: &[u8],
        signature: &[u8],
        public_key: &[u8],
        merkle_root: &[u8],
        siblings_json: &[u8],
    ) -> Result<JsValue, JsValue> {
        let algorithm = Algorithm::MLDSA65;
        let sig_valid = pqc::verify(&algorithm, receipt_data, signature, public_key)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let siblings: Vec<Vec<u8>> = serde_json::from_slice(siblings_json)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let proof = MerkleProof {
            leaf: receipt_data.to_vec(),
            leaf_index: 0,
            siblings,
            path: vec![true; siblings.len()],
        };
        let proof_valid = MerkleTree::verify_proof(&proof, merkle_root);
        let result = js_sys::Object::new();
        js_sys::Reflect::set(
            &result,
            &JsValue::from_str("signatureValid"),
            &JsValue::from_bool(sig_valid),
        ).map_err(|_| JsValue::from_str("failed to set signatureValid"))?;
        js_sys::Reflect::set(
            &result,
            &JsValue::from_str("merkleProofValid"),
            &JsValue::from_bool(proof_valid),
        ).map_err(|_| JsValue::from_str("failed to set merkleProofValid"))?;
        Ok(JsValue::from(result))
    }

    pub fn pqc_sign(algorithm_name: &str, message: &[u8], secret_key: &[u8]) -> Result<js_sys::Uint8Array, JsValue> {
        let algorithm = parse_sign_algorithm(algorithm_name)?;
        let mut combined = Vec::new();
        combined.extend_from_slice(message);
        combined.extend_from_slice(b"@DGSN-PQC");
        let sig = pqc::sign(&algorithm, &combined, secret_key)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        Ok(js_sys::Uint8Array::from(&sig[..]))
    }

    pub fn circuit_validate(
        circuit_data: &[u8],
        verifying_key_json: &[u8],
    ) -> Result<JsValue, JsValue> {
        let vk: crate::zkp::noir::NoirVerifyingKey = serde_json::from_slice(verifying_key_json)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let proof = ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Single(circuit_data.to_vec()),
            vec![],
        );
        let valid = NoirBackend::verify_proof(&vk, &proof, &[])
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let result = js_sys::Object::new();
        js_sys::Reflect::set(
            &result,
            &JsValue::from_str("valid"),
            &JsValue::from_bool(valid),
        ).map_err(|_| JsValue::from_str("failed to set valid"))?;
        Ok(JsValue::from(result))
    }
}

#[wasm_bindgen]
pub fn verify_receipt(receipt_json: &str, signature_hex: &str, public_key_hex: &str) -> bool {
    let signature = match hex::decode(signature_hex) {
        Ok(s) => s,
        Err(_) => return false,
    };
    let public_key = match hex::decode(public_key_hex) {
        Ok(pk) => pk,
        Err(_) => return false,
    };
    let receipt_bytes = receipt_json.as_bytes();

    let algorithm = Algorithm::MLDSA65;
    pqc::verify(&algorithm, receipt_bytes, &signature, &public_key).unwrap_or(false)
}

#[wasm_bindgen]
pub fn generate_keypair() -> JsValue {
    let result = js_sys::Object::new();

    let algorithm = Algorithm::MLDSA65;
    match pqc::keygen(algorithm) {
        Ok((pk, sk)) => {
            let pk_hex = hex::encode(&pk);
            let sk_hex = hex::encode(&sk);
            js_sys::Reflect::set(&result, &JsValue::from_str("publicKey"), &JsValue::from_str(&pk_hex)).ok();
            js_sys::Reflect::set(&result, &JsValue::from_str("secretKey"), &JsValue::from_str(&sk_hex)).ok();
            js_sys::Reflect::set(&result, &JsValue::from_str("algorithm"), &JsValue::from_str("ML-DSA-65")).ok();
        }
        Err(e) => {
            js_sys::Reflect::set(&result, &JsValue::from_str("error"), &JsValue::from_str(&e.to_string())).ok();
        }
    }

    JsValue::from(result)
}

#[wasm_bindgen]
pub fn merkle_proof(leaves: Vec<String>, index: usize) -> JsValue {
    let result = js_sys::Object::new();

    let leaf_bytes: Vec<Vec<u8>> = leaves.iter().map(|s| s.as_bytes().to_vec()).collect();

    if index >= leaf_bytes.len() {
        js_sys::Reflect::set(
            &result,
            &JsValue::from_str("error"),
            &JsValue::from_str("index out of bounds"),
        ).ok();
        return JsValue::from(result);
    }

    match MerkleTree::from_leaves(&leaf_bytes) {
        Ok(tree) => {
            let root_hex = hex::encode(tree.root().unwrap_or(&[]));
            js_sys::Reflect::set(&result, &JsValue::from_str("root"), &JsValue::from_str(&root_hex)).ok();

            match tree.generate_proof(index) {
                Ok(proof) => {
                    let siblings_hex: Vec<String> = proof.siblings.iter().map(|s| hex::encode(s)).collect();
                    let siblings_arr = js_sys::Array::new();
                    for s in &siblings_hex {
                        siblings_arr.push(&JsValue::from_str(s));
                    }
                    js_sys::Reflect::set(&result, &JsValue::from_str("siblings"), &siblings_arr).ok();
                    js_sys::Reflect::set(
                        &result,
                        &JsValue::from_str("leafIndex"),
                        &JsValue::from_f64(proof.leaf_index as f64),
                    ).ok();
                    js_sys::Reflect::set(
                        &result,
                        &JsValue::from_str("leaf"),
                        &JsValue::from_str(&hex::encode(&proof.leaf)),
                    ).ok();

                    let path_bits: Vec<bool> = proof.path;
                    let path_arr = js_sys::Array::new();
                    for bit in &path_bits {
                        path_arr.push(&JsValue::from_bool(*bit));
                    }
                    js_sys::Reflect::set(&result, &JsValue::from_str("path"), &path_arr).ok();
                }
                Err(e) => {
                    js_sys::Reflect::set(
                        &result,
                        &JsValue::from_str("error"),
                        &JsValue::from_str(&e.to_string()),
                    ).ok();
                }
            }
        }
        Err(e) => {
            js_sys::Reflect::set(
                &result,
                &JsValue::from_str("error"),
                &JsValue::from_str(&e.to_string()),
            ).ok();
        }
    }

    JsValue::from(result)
}

fn parse_algorithm(name: &str) -> Result<Algorithm, JsValue> {
    match name {
        "ML-KEM-512" => Ok(Algorithm::MLKEM512),
        "ML-KEM-768" => Ok(Algorithm::MLKEM768),
        "ML-KEM-1024" => Ok(Algorithm::MLKEM1024),
        "ML-DSA-44" => Ok(Algorithm::MLDSA44),
        "ML-DSA-65" => Ok(Algorithm::MLDSA65),
        "ML-DSA-87" => Ok(Algorithm::MLDSA87),
        "SLH-DSA-128f" => Ok(Algorithm::SLHDSA128F),
        "SLH-DSA-192s" => Ok(Algorithm::SLHDSA192S),
        "SLH-DSA-256f" => Ok(Algorithm::SLHDSA256F),
        _ => Err(JsValue::from_str(&format!("unsupported algorithm: {}", name))),
    }
}

fn parse_sign_algorithm(name: &str) -> Result<Algorithm, JsValue> {
    match name {
        "ML-DSA-44" => Ok(Algorithm::MLDSA44),
        "ML-DSA-65" => Ok(Algorithm::MLDSA65),
        "ML-DSA-87" => Ok(Algorithm::MLDSA87),
        "SLH-DSA-128f" => Ok(Algorithm::SLHDSA128F),
        "SLH-DSA-192s" => Ok(Algorithm::SLHDSA192S),
        "SLH-DSA-256f" => Ok(Algorithm::SLHDSA256F),
        _ => Err(JsValue::from_str(&format!("unsupported signing algorithm: {}", name))),
    }
}

#[wasm_bindgen]
pub fn init_crypto() -> Result<WasmCrypto, JsValue> {
    Ok(WasmCrypto::new())
}
