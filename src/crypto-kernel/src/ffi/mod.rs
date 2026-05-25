use crate::pqc::{self, Algorithm};
use std::ptr;

const ALG_MLKEM512: u8 = 0;
const ALG_MLKEM768: u8 = 1;
const ALG_MLKEM1024: u8 = 2;
const ALG_MLDSA44: u8 = 3;
const ALG_MLDSA65: u8 = 4;
const ALG_MLDSA87: u8 = 5;
const ALG_SLHDSA128F: u8 = 6;
const ALG_SLHDSA192S: u8 = 7;
const ALG_SLHDSA256F: u8 = 8;

const ERR_SUCCESS: i32 = 0;
const ERR_NULL_POINTER: i32 = -1;
const ERR_INVALID_ALGORITHM: i32 = -2;
const ERR_OPERATION_FAILED: i32 = -3;
const ERR_BUFFER_TOO_SMALL: i32 = -4;
const ERR_INVALID_KEY: i32 = -5;
const ERR_VERIFICATION_FAILED: i32 = -6;

fn alg_from_u8(alg: u8) -> Result<Algorithm, i32> {
    match alg {
        ALG_MLKEM512 => Ok(Algorithm::MLKEM512),
        ALG_MLKEM768 => Ok(Algorithm::MLKEM768),
        ALG_MLKEM1024 => Ok(Algorithm::MLKEM1024),
        ALG_MLDSA44 => Ok(Algorithm::MLDSA44),
        ALG_MLDSA65 => Ok(Algorithm::MLDSA65),
        ALG_MLDSA87 => Ok(Algorithm::MLDSA87),
        ALG_SLHDSA128F => Ok(Algorithm::SLHDSA128F),
        ALG_SLHDSA192S => Ok(Algorithm::SLHDSA192S),
        ALG_SLHDSA256F => Ok(Algorithm::SLHDSA256F),
        _ => Err(ERR_INVALID_ALGORITHM),
    }
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_keygen(
    alg: u8,
    pk_out: *mut u8,
    pk_out_len: *mut usize,
    sk_out: *mut u8,
    sk_out_len: *mut usize,
) -> i32 {
    if pk_out.is_null() || pk_out_len.is_null() || sk_out.is_null() || sk_out_len.is_null() {
        return ERR_NULL_POINTER;
    }

    let algorithm = match alg_from_u8(alg) {
        Ok(a) => a,
        Err(e) => return e,
    };

    let (pk, sk) = match pqc::keygen(algorithm) {
        Ok(pair) => pair,
        Err(_) => return ERR_OPERATION_FAILED,
    };

    let pk_cap = *pk_out_len;
    let sk_cap = *sk_out_len;

    if pk.len() > pk_cap || sk.len() > sk_cap {
        *pk_out_len = pk.len();
        *sk_out_len = sk.len();
        return ERR_BUFFER_TOO_SMALL;
    }

    ptr::copy_nonoverlapping(pk.as_ptr(), pk_out, pk.len());
    *pk_out_len = pk.len();

    ptr::copy_nonoverlapping(sk.as_ptr(), sk_out, sk.len());
    *sk_out_len = sk.len();

    ERR_SUCCESS
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_sign(
    sk: *const u8,
    sk_len: usize,
    msg: *const u8,
    msg_len: usize,
    sig_out: *mut u8,
    sig_out_len: *mut usize,
) -> i32 {
    if sk.is_null() || msg.is_null() || sig_out.is_null() || sig_out_len.is_null() {
        return ERR_NULL_POINTER;
    }

    let sk_slice = std::slice::from_raw_parts(sk, sk_len);
    let msg_slice = std::slice::from_raw_parts(msg, msg_len);
    let sig_cap = *sig_out_len;

    let mut last_err = ERR_OPERATION_FAILED;
    for algorithm in &[
        Algorithm::MLDSA44,
        Algorithm::MLDSA65,
        Algorithm::MLDSA87,
        Algorithm::SLHDSA128F,
        Algorithm::SLHDSA192S,
        Algorithm::SLHDSA256F,
    ] {
        match pqc::sign(algorithm, msg_slice, sk_slice) {
            Ok(sig) => {
                if sig.len() > sig_cap {
                    *sig_out_len = sig.len();
                    return ERR_BUFFER_TOO_SMALL;
                }
                ptr::copy_nonoverlapping(sig.as_ptr(), sig_out, sig.len());
                *sig_out_len = sig.len();
                return ERR_SUCCESS;
            }
            Err(e) => {
                last_err = ERR_OPERATION_FAILED;
                let _ = e;
            }
        }
    }

    last_err
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_verify(
    pk: *const u8,
    pk_len: usize,
    msg: *const u8,
    msg_len: usize,
    sig: *const u8,
    sig_len: usize,
) -> i32 {
    if pk.is_null() || msg.is_null() || sig.is_null() {
        return ERR_NULL_POINTER;
    }

    let pk_slice = std::slice::from_raw_parts(pk, pk_len);
    let msg_slice = std::slice::from_raw_parts(msg, msg_len);
    let sig_slice = std::slice::from_raw_parts(sig, sig_len);

    for algorithm in &[
        Algorithm::MLDSA44,
        Algorithm::MLDSA65,
        Algorithm::MLDSA87,
        Algorithm::SLHDSA128F,
        Algorithm::SLHDSA192S,
        Algorithm::SLHDSA256F,
    ] {
        match pqc::verify(algorithm, msg_slice, sig_slice, pk_slice) {
            Ok(true) => return ERR_SUCCESS,
            Ok(false) => continue,
            Err(_) => continue,
        }
    }

    ERR_VERIFICATION_FAILED
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_kem_encapsulate(
    pk: *const u8,
    pk_len: usize,
    ct_out: *mut u8,
    ct_out_len: *mut usize,
    ss_out: *mut u8,
    ss_out_len: *mut usize,
) -> i32 {
    if pk.is_null() || ct_out.is_null() || ct_out_len.is_null() || ss_out.is_null() || ss_out_len.is_null() {
        return ERR_NULL_POINTER;
    }

    let pk_slice = std::slice::from_raw_parts(pk, pk_len);

    let (ct, ss) = match pqc::kyber::encapsulate(pk_slice) {
        Ok(pair) => pair,
        Err(_) => return ERR_OPERATION_FAILED,
    };

    let ct_cap = *ct_out_len;
    let ss_cap = *ss_out_len;

    if ct.len() > ct_cap || ss.len() > ss_cap {
        *ct_out_len = ct.len();
        *ss_out_len = ss.len();
        return ERR_BUFFER_TOO_SMALL;
    }

    ptr::copy_nonoverlapping(ct.as_ptr(), ct_out, ct.len());
    *ct_out_len = ct.len();

    ptr::copy_nonoverlapping(ss.as_ptr(), ss_out, ss.len());
    *ss_out_len = ss.len();

    ERR_SUCCESS
}

#[no_mangle]
pub unsafe extern "C" fn dgsn_kem_decapsulate(
    sk: *const u8,
    sk_len: usize,
    ct: *const u8,
    ct_len: usize,
    ss_out: *mut u8,
    ss_out_len: *mut usize,
) -> i32 {
    if sk.is_null() || ct.is_null() || ss_out.is_null() || ss_out_len.is_null() {
        return ERR_NULL_POINTER;
    }

    let sk_slice = std::slice::from_raw_parts(sk, sk_len);
    let ct_slice = std::slice::from_raw_parts(ct, ct_len);

    let ss = match pqc::kyber::decapsulate(ct_slice, sk_slice) {
        Ok(s) => s,
        Err(_) => return ERR_OPERATION_FAILED,
    };

    let ss_cap = *ss_out_len;
    if ss.len() > ss_cap {
        *ss_out_len = ss.len();
        return ERR_BUFFER_TOO_SMALL;
    }

    ptr::copy_nonoverlapping(ss.as_ptr(), ss_out, ss.len());
    *ss_out_len = ss.len();

    ERR_SUCCESS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dgsn_keygen_mlkem768() {
        let mut pk = [0u8; 1184];
        let mut pk_len = pk.len();
        let mut sk = [0u8; 2400];
        let mut sk_len = sk.len();

        let ret = unsafe {
            dgsn_keygen(ALG_MLKEM768, pk.as_mut_ptr(), &mut pk_len, sk.as_mut_ptr(), &mut sk_len)
        };
        assert_eq!(ret, ERR_SUCCESS);
        assert!(pk_len > 0);
        assert!(sk_len > 0);
    }

    #[test]
    fn test_dgsn_keygen_mldsa65() {
        let mut pk = [0u8; 1952];
        let mut pk_len = pk.len();
        let mut sk = [0u8; 4000];
        let mut sk_len = sk.len();

        let ret = unsafe {
            dgsn_keygen(ALG_MLDSA65, pk.as_mut_ptr(), &mut pk_len, sk.as_mut_ptr(), &mut sk_len)
        };
        assert_eq!(ret, ERR_SUCCESS);
    }

    #[test]
    fn test_dgsn_keygen_invalid_algorithm() {
        let mut pk = [0u8; 32];
        let mut pk_len = pk.len();
        let mut sk = [0u8; 32];
        let mut sk_len = sk.len();

        let ret = unsafe {
            dgsn_keygen(99, pk.as_mut_ptr(), &mut pk_len, sk.as_mut_ptr(), &mut sk_len)
        };
        assert_eq!(ret, ERR_INVALID_ALGORITHM);
    }

    #[test]
    fn test_dgsn_sign_verify_roundtrip() {
        let mut pk = [0u8; 1952];
        let mut pk_len = pk.len();
        let mut sk = [0u8; 4000];
        let mut sk_len = sk.len();

        let ret = unsafe {
            dgsn_keygen(ALG_MLDSA65, pk.as_mut_ptr(), &mut pk_len, sk.as_mut_ptr(), &mut sk_len)
        };
        assert_eq!(ret, ERR_SUCCESS);

        let msg = b"test message for signing";
        let mut sig = [0u8; 4627];
        let mut sig_len = sig.len();

        let ret = unsafe {
            dgsn_sign(sk.as_ptr(), sk_len, msg.as_ptr(), msg.len(), sig.as_mut_ptr(), &mut sig_len)
        };
        assert_eq!(ret, ERR_SUCCESS);
        assert!(sig_len > 0);

        let ret = unsafe {
            dgsn_verify(pk.as_ptr(), pk_len, msg.as_ptr(), msg.len(), sig.as_ptr(), sig_len)
        };
        assert_eq!(ret, ERR_SUCCESS);
    }

    #[test]
    fn test_dgsn_verify_failure() {
        let pk = b"fake-public-key-00000000000000000000";
        let msg = b"test message";
        let sig = b"fake-signature";

        let ret = unsafe {
            dgsn_verify(pk.as_ptr(), pk.len(), msg.as_ptr(), msg.len(), sig.as_ptr(), sig.len())
        };
        assert_eq!(ret, ERR_VERIFICATION_FAILED);
    }

    #[test]
    fn test_dgsn_null_pointers() {
        let ret = unsafe { dgsn_keygen(ALG_MLKEM768, ptr::null_mut(), &mut 0usize, ptr::null_mut(), &mut 0usize) };
        assert_eq!(ret, ERR_NULL_POINTER);

        let ret = unsafe { dgsn_sign(ptr::null(), 0, ptr::null(), 0, ptr::null_mut(), &mut 0usize) };
        assert_eq!(ret, ERR_NULL_POINTER);
    }
}
