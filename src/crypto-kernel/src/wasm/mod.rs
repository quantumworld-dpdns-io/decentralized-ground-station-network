use crate::pqc::{self, Algorithm};
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct WasmCrypto;

#[wasm_bindgen]
impl WasmCrypto {
    pub fn new() -> Self {
        WasmCrypto
    }

    pub fn keygen(algorithm_name: &str) -> Result<JsValue, JsValue> {
        let algorithm = match algorithm_name {
            "ML-KEM-512" => Algorithm::MLKEM512,
            "ML-KEM-768" => Algorithm::MLKEM768,
            "ML-KEM-1024" => Algorithm::MLKEM1024,
            "ML-DSA-44" => Algorithm::MLDSA44,
            "ML-DSA-65" => Algorithm::MLDSA65,
            "ML-DSA-87" => Algorithm::MLDSA87,
            "SLH-DSA-128f" => Algorithm::SLHDSA128F,
            "SLH-DSA-192s" => Algorithm::SLHDSA192S,
            "SLH-DSA-256f" => Algorithm::SLHDSA256F,
            _ => return Err(JsValue::from_str(&format!("unsupported algorithm: {}", algorithm_name))),
        };

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
        let algorithm = match algorithm_name {
            "ML-DSA-44" => Algorithm::MLDSA44,
            "ML-DSA-65" => Algorithm::MLDSA65,
            "ML-DSA-87" => Algorithm::MLDSA87,
            "SLH-DSA-128f" => Algorithm::SLHDSA128F,
            "SLH-DSA-192s" => Algorithm::SLHDSA192S,
            "SLH-DSA-256f" => Algorithm::SLHDSA256F,
            _ => return Err(JsValue::from_str(&format!("unsupported signing algorithm: {}", algorithm_name))),
        };

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
        let algorithm = match algorithm_name {
            "ML-DSA-44" => Algorithm::MLDSA44,
            "ML-DSA-65" => Algorithm::MLDSA65,
            "ML-DSA-87" => Algorithm::MLDSA87,
            "SLH-DSA-128f" => Algorithm::SLHDSA128F,
            "SLH-DSA-192s" => Algorithm::SLHDSA192S,
            "SLH-DSA-256f" => Algorithm::SLHDSA256F,
            _ => return Err(JsValue::from_str(&format!("unsupported verify algorithm: {}", algorithm_name))),
        };

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
}

#[wasm_bindgen]
pub fn init_crypto() -> Result<WasmCrypto, JsValue> {
    Ok(WasmCrypto::new())
}
