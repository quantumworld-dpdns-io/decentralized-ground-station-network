use crate::merkle::MerkleTree;
use crate::pqc::{self, Algorithm};
use crate::zkp::{self, ProofSystem, ProofType, ZkpProof};
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
    ) -> Result<JsValue, JsValue> {
        let algorithm = Algorithm::MLDSA65;
        let sig_valid = pqc::verify(&algorithm, receipt_data, signature, public_key)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let mt = MerkleTree::from_root(merkle_root)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let proof_valid = mt.verify_inclusion(receipt_data, merkle_root)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
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
        public_inputs: JsValue,
    ) -> Result<JsValue, JsValue> {
        let inputs_array: js_sys::Array = public_inputs.dyn_into()
            .map_err(|_| JsValue::from_str("public_inputs must be an array"))?;
        let mut inputs = Vec::new();
        for i in 0..inputs_array.length() {
            let val = inputs_array.get(i);
            if let Some(arr) = val.dyn_ref::<js_sys::Array>() {
                let mut inner = Vec::with_capacity(arr.length() as usize);
                for j in 0..arr.length() {
                    let byte_val = arr.get(j).as_f64()
                        .ok_or_else(|| JsValue::from_str("invalid byte value"))? as u8;
                    inner.push(byte_val);
                }
                inputs.push(inner);
            }
        }
        let proof = ZkpProof {
            proof_type: ProofType::Groth16,
            proof_data: circuit_data.to_vec(),
            public_inputs: inputs,
            system: ProofSystem::Noir,
            verified: false,
        };
        let valid = zkp::verify(&proof)
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
