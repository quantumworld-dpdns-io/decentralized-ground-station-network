use crate::pqc::{self, Algorithm};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[derive(Clone)]
#[repr(C)]
pub struct FfiResult {
    pub success: bool,
    pub data: *mut u8,
    pub data_len: usize,
    pub error_message: *mut c_char,
}

impl FfiResult {
    fn ok(data: Vec<u8>) -> Self {
        let len = data.len();
        let ptr = data.leak().as_mut_ptr();
        FfiResult {
            success: true,
            data: ptr,
            data_len: len,
            error_message: std::ptr::null_mut(),
        }
    }

    fn err(msg: &str) -> Self {
        let c_msg = CString::new(msg).unwrap_or_default();
        FfiResult {
            success: false,
            data: std::ptr::null_mut(),
            data_len: 0,
            error_message: c_msg.into_raw(),
        }
    }

    fn bool(val: bool) -> Self {
        let data = vec![val as u8];
        Self::ok(data)
    }
}

unsafe fn free_result(res: &mut FfiResult) {
    if !res.data.is_null() {
        let _ = Vec::from_raw_parts(res.data, res.data_len, res.data_len);
        res.data = std::ptr::null_mut();
    }
    if !res.error_message.is_null() {
        let _ = CString::from_raw(res.error_message);
        res.error_message = std::ptr::null_mut();
    }
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_keygen(
    algorithm_name: *const c_char,
) -> FfiResult {
    if algorithm_name.is_null() {
        return FfiResult::err("null algorithm name");
    }

    let name = match CStr::from_ptr(algorithm_name).to_str() {
        Ok(s) => s,
        Err(e) => return FfiResult::err(&format!("invalid UTF-8: {}", e)),
    };

    let algorithm = match name {
        "ML-KEM-512" => Algorithm::MLKEM512,
        "ML-KEM-768" => Algorithm::MLKEM768,
        "ML-KEM-1024" => Algorithm::MLKEM1024,
        "ML-DSA-44" => Algorithm::MLDSA44,
        "ML-DSA-65" => Algorithm::MLDSA65,
        "ML-DSA-87" => Algorithm::MLDSA87,
        "SLH-DSA-128f" => Algorithm::SLHDSA128F,
        "SLH-DSA-192s" => Algorithm::SLHDSA192S,
        "SLH-DSA-256f" => Algorithm::SLHDSA256F,
        _ => return FfiResult::err(&format!("unsupported algorithm: {}", name)),
    };

    match pqc::keygen(algorithm) {
        Ok((pk, sk)) => {
            let mut combined = Vec::with_capacity(8 + pk.len() + sk.len());
            combined.extend_from_slice(&(pk.len() as u64).to_le_bytes());
            combined.extend_from_slice(&pk);
            combined.extend_from_slice(&sk);
            FfiResult::ok(combined)
        }
        Err(e) => FfiResult::err(&e.to_string()),
    }
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_sign(
    algorithm_name: *const c_char,
    message: *const u8,
    message_len: usize,
    secret_key: *const u8,
    secret_key_len: usize,
) -> FfiResult {
    if algorithm_name.is_null() || message.is_null() || secret_key.is_null() {
        return FfiResult::err("null pointer argument");
    }

    let name = match CStr::from_ptr(algorithm_name).to_str() {
        Ok(s) => s,
        Err(e) => return FfiResult::err(&format!("invalid UTF-8: {}", e)),
    };

    let algorithm = match name {
        "ML-DSA-44" => Algorithm::MLDSA44,
        "ML-DSA-65" => Algorithm::MLDSA65,
        "ML-DSA-87" => Algorithm::MLDSA87,
        "SLH-DSA-128f" => Algorithm::SLHDSA128F,
        "SLH-DSA-192s" => Algorithm::SLHDSA192S,
        "SLH-DSA-256f" => Algorithm::SLHDSA256F,
        _ => return FfiResult::err(&format!("unsupported signing algorithm: {}", name)),
    };

    let msg_slice = std::slice::from_raw_parts(message, message_len);
    let sk_slice = std::slice::from_raw_parts(secret_key, secret_key_len);

    match pqc::sign(&algorithm, msg_slice, sk_slice) {
        Ok(sig) => FfiResult::ok(sig),
        Err(e) => FfiResult::err(&e.to_string()),
    }
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_verify(
    algorithm_name: *const c_char,
    message: *const u8,
    message_len: usize,
    signature: *const u8,
    signature_len: usize,
    public_key: *const u8,
    public_key_len: usize,
) -> FfiResult {
    if algorithm_name.is_null() || message.is_null() || signature.is_null() || public_key.is_null() {
        return FfiResult::err("null pointer argument");
    }

    let name = match CStr::from_ptr(algorithm_name).to_str() {
        Ok(s) => s,
        Err(e) => return FfiResult::err(&format!("invalid UTF-8: {}", e)),
    };

    let algorithm = match name {
        "ML-DSA-44" => Algorithm::MLDSA44,
        "ML-DSA-65" => Algorithm::MLDSA65,
        "ML-DSA-87" => Algorithm::MLDSA87,
        "SLH-DSA-128f" => Algorithm::SLHDSA128F,
        "SLH-DSA-192s" => Algorithm::SLHDSA192S,
        "SLH-DSA-256f" => Algorithm::SLHDSA256F,
        _ => return FfiResult::err(&format!("unsupported verify algorithm: {}", name)),
    };

    let msg_slice = std::slice::from_raw_parts(message, message_len);
    let sig_slice = std::slice::from_raw_parts(signature, signature_len);
    let pk_slice = std::slice::from_raw_parts(public_key, public_key_len);

    match pqc::verify(&algorithm, msg_slice, sig_slice, pk_slice) {
        Ok(valid) => FfiResult::bool(valid),
        Err(e) => FfiResult::err(&e.to_string()),
    }
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_free_result(res: &mut FfiResult) {
    free_result(res);
}

#[no_mangle]
pub extern "C" fn dgsn_version() -> *mut c_char {
    CString::new(crate::VERSION)
        .unwrap_or_default()
        .into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_free_string(s: *mut c_char) {
    if !s.is_null() {
        let _ = CString::from_raw(s);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn test_ffi_keygen() {
        let algo = CString::new("ML-KEM-768").unwrap();
        let result = unsafe { dgsn_keygen(algo.as_ptr()) };
        assert!(result.success);
        assert!(!result.data.is_null());
        assert!(result.data_len > 0);
        unsafe { dgsn_free_result(&mut std::mem::transmute::<_, FfiResult>(result.clone())) };
    }

    #[test]
    fn test_ffi_version() {
        let ptr = dgsn_version();
        assert!(!ptr.is_null());
        unsafe {
            let version = CStr::from_ptr(ptr).to_str().unwrap();
            assert!(!version.is_empty());
            dgsn_free_string(ptr);
        }
    }

    #[test]
    fn test_ffi_invalid_algorithm() {
        let algo = CString::new("INVALID").unwrap();
        let result = unsafe { dgsn_keygen(algo.as_ptr()) };
        assert!(!result.success);
        assert!(result.data.is_null());
    }
}
