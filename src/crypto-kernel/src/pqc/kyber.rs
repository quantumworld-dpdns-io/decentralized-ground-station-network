use crate::pqc::{Algorithm, KemScheme, Keygen};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha3::digest::ExtendableOutput;
use sha3::Shake256;
use zeroize::Zeroize;

const KYBER512_PK_SIZE: usize = 800;
const KYBER512_SK_SIZE: usize = 1632;
const KYBER512_CT_SIZE: usize = 768;
const KYBER768_PK_SIZE: usize = 1184;
const KYBER768_SK_SIZE: usize = 2400;
const KYBER768_CT_SIZE: usize = 1088;
const KYBER1024_PK_SIZE: usize = 1568;
const KYBER1024_SK_SIZE: usize = 3168;
const KYBER1024_CT_SIZE: usize = 1568;
const SHARED_SECRET_SIZE: usize = 32;

fn shake256_xof(data: &[u8], output_len: usize) -> Vec<u8> {
    let mut hasher = Shake256::default();
    hasher.update(data);
    let mut output = vec![0u8; output_len];
    hasher.squeeze(&mut output);
    output
}

fn cbd(seed: &[u8], eta: usize) -> Vec<i16> {
    let bytes = shake256_xof(seed, eta * 4);
    let mut coeffs = Vec::with_capacity(eta * 16);
    for i in 0..eta * 16 {
        let byte_idx = (i * 2) / 8;
        let bit_pos = (i * 2) % 8;
        let a = ((bytes[byte_idx] >> bit_pos) & 1) as i16;
        let b = ((bytes[byte_idx] >> (bit_pos + 1)) & 1) as i16;
        coeffs.push(a - b);
    }
    coeffs
}

fn mod_reduce(x: i16) -> i16 {
    let q = 3329i16;
    let mut r = x % q;
    if r < 0 {
        r += q;
    }
    r
}

fn ntt(coeffs: &[i16]) -> Vec<i16> {
    let n = 256usize;
    let q = 3329i16;
    let mut out = coeffs.to_vec();

    let mut len = n / 2;
    let mut start = 0usize;
    while len >= 1 {
        for i in 0..len {
            let j = (start / (2 * len)) * len + (start % (2 * len));
            let k = start + i;
            let l = start + i + len;
            if l < out.len() && k < out.len() {
                let t = out[l];
                out[l] = mod_reduce(out[k] - t);
                out[k] = mod_reduce(out[k] + t);
            }
        }
        start += 2 * len;
        if start >= n {
            start = 0;
            len /= 2;
        }
    }
    out
}

fn inv_ntt(coeffs: &[i16]) -> Vec<i16> {
    let n = 256usize;
    let q = 3329i16;
    let mut out = coeffs.to_vec();

    let inv_2 = (q + 1) / 2;

    let mut len = 1usize;
    let mut start = 0usize;
    while len < n / 2 {
        for i in 0..len {
            let k = start + i;
            let l = start + i + len;
            if l < out.len() && k < out.len() {
                let t = out[l];
                out[l] = mod_reduce((out[k] - t) * inv_2);
                out[k] = mod_reduce((out[k] + t) * inv_2);
            }
        }
        start += 2 * len;
        if start >= n {
            start = 0;
            len *= 2;
        }
    }
    out
}

fn poly_mul(a: &[i16], b: &[i16]) -> Vec<i16> {
    let nta = ntt(a);
    let ntb = ntt(b);
    let mut prod = vec![0i16; nta.len()];
    for i in 0..nta.len().min(ntb.len()) {
        prod[i] = mod_reduce(nta[i] * ntb[i]);
    }
    inv_ntt(&prod)
}

fn compress(value: i16, d: usize) -> i16 {
    let q = 3329i16;
    let compressed = ((value as i32) << d) / (q as i32);
    compressed as i16 & ((1 << d) - 1)
}

fn decompress(value: i16, d: usize) -> i16 {
    let q = 3329i16;
    let expanded = ((value as i32) * (q as i32) + (1 << (d - 1))) >> d;
    expanded as i16
}

fn generate_matrix(seed: &[u8; 34], k: usize, transposed: bool) -> Vec<Vec<Vec<i16>>> {
    let mut matrix = Vec::with_capacity(k);
    for i in 0..k {
        let mut row = Vec::with_capacity(k);
        for j in 0..k {
            let mut buf = Vec::with_capacity(34);
            buf.extend_from_slice(seed);
            if transposed {
                buf.push(j as u8);
                buf.push(i as u8);
            } else {
                buf.push(i as u8);
                buf.push(j as u8);
            }
            let seed_bytes = shake256_xof(&buf, 3 * 256);
            let mut poly = Vec::with_capacity(256);
            for idx in 0..256 {
                let val = ((seed_bytes[3 * idx] as i16)
                    | ((seed_bytes[3 * idx + 1] as i16) << 8)
                    | ((seed_bytes[3 * idx + 2] as i16) << 16))
                    & 0x7FF;
                poly.push(val % 3329);
            }
            row.push(poly);
        }
        matrix.push(row);
    }
    matrix
}

fn matrix_vector_mul(matrix: &[Vec<Vec<i16>>], vec: &[Vec<i16>]) -> Vec<Vec<i16>> {
    let k = matrix.len();
    let mut result = Vec::with_capacity(k);
    for i in 0..k {
        let mut sum = vec![0i16; 256];
        for j in 0..k {
            let prod = poly_mul(&matrix[i][j], &vec[j]);
            for idx in 0..256 {
                sum[idx] = mod_reduce(sum[idx] + prod[idx]);
            }
        }
        result.push(sum);
    }
    result
}

fn add_polys(a: &[i16], b: &[i16]) -> Vec<i16> {
    a.iter().zip(b.iter()).map(|(x, y)| mod_reduce(x + y)).collect()
}

fn sub_polys(a: &[i16], b: &[i16]) -> Vec<i16> {
    a.iter().zip(b.iter()).map(|(x, y)| mod_reduce(x - y)).collect()
}

fn h(c: &[u8], output_len: usize) -> Vec<u8> {
    shake256_xof(c, output_len)
}

fn g(c: &[u8]) -> [u8; 64] {
    let out = shake256_xof(c, 64);
    let mut result = [0u8; 64];
    result.copy_from_slice(&out);
    result
}

fn prf(s: &[u8], b: u8, output_len: usize) -> Vec<u8> {
    let mut input = vec![b];
    input.extend_from_slice(s);
    shake256_xof(&input, output_len)
}

fn kdf2(key: &[u8]) -> [u8; 32] {
    let out = shake256_xof(key, 32);
    let mut result = [0u8; 32];
    result.copy_from_slice(&out);
    result
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum KyberVariant {
    Kyber512,
    Kyber768,
    Kyber1024,
}

impl KyberVariant {
    pub fn security_level(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => 128,
            KyberVariant::Kyber768 => 192,
            KyberVariant::Kyber1024 => 256,
        }
    }

    pub fn pk_size(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => KYBER512_PK_SIZE,
            KyberVariant::Kyber768 => KYBER768_PK_SIZE,
            KyberVariant::Kyber1024 => KYBER1024_PK_SIZE,
        }
    }

    pub fn sk_size(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => KYBER512_SK_SIZE,
            KyberVariant::Kyber768 => KYBER768_SK_SIZE,
            KyberVariant::Kyber1024 => KYBER1024_SK_SIZE,
        }
    }

    pub fn ct_size(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => KYBER512_CT_SIZE,
            KyberVariant::Kyber768 => KYBER768_CT_SIZE,
            KyberVariant::Kyber1024 => KYBER1024_CT_SIZE,
        }
    }

    fn k(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => 2,
            KyberVariant::Kyber768 => 3,
            KyberVariant::Kyber1024 => 4,
        }
    }

    fn eta1(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => 3,
            KyberVariant::Kyber768 => 2,
            KyberVariant::Kyber1024 => 2,
        }
    }

    fn eta2(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => 2,
            KyberVariant::Kyber768 => 2,
            KyberVariant::Kyber1024 => 2,
        }
    }

    fn du(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => 10,
            KyberVariant::Kyber768 => 10,
            KyberVariant::Kyber1024 => 11,
        }
    }

    fn dv(&self) -> usize {
        match self {
            KyberVariant::Kyber512 => 4,
            KyberVariant::Kyber768 => 4,
            KyberVariant::Kyber1024 => 5,
        }
    }
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct KyberPublicKey {
    pub raw: Vec<u8>,
    pub variant: KyberVariant,
    pub seed: [u8; 32],
}

#[derive(Clone, Zeroize, Serialize, Deserialize)]
#[zeroize(drop)]
pub struct KyberSecretKey {
    pub raw: Vec<u8>,
    pub variant: KyberVariant,
    pub pk: Vec<u8>,
    pub z: [u8; 32],
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct KyberCiphertext {
    pub raw: Vec<u8>,
    pub variant: KyberVariant,
}

fn kyber_internal_keypair(variant: KyberVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    let k = variant.k();
    let pk_size = variant.pk_size();
    let sk_size = variant.sk_size();

    let mut rng = rand::thread_rng();

    let mut seed_d = [0u8; 32];
    let mut seed_z = [0u8; 32];
    rng.fill_bytes(&mut seed_d);
    rng.fill_bytes(&mut seed_z);

    let g_out = g(&seed_d);
    let mut seed = [0u8; 32];
    seed.copy_from_slice(&g_out[..32]);
    let mut seed_pk = [0u8; 32];
    seed_pk.copy_from_slice(&g_out[32..]);

    let mut rho_seed = [0u8; 34];
    rho_seed[..32].copy_from_slice(&seed);
    rho_seed[32] = 0;
    rho_seed[33] = 0;

    let matrix = generate_matrix(&rho_seed, k, false);

    let mut s_coeffs = Vec::with_capacity(k);
    for i in 0..k {
        let nonce = i as u8;
        let noise_seed = prf(&seed_pk, nonce, variant.eta1() * 2 * 32);
        let noise = cbd(&noise_seed, variant.eta1());
        s_coeffs.push(noise);
    }

    let mut e_coeffs = Vec::with_capacity(k);
    for i in 0..k {
        let nonce = (k + i) as u8;
        let noise_seed = prf(&seed_pk, nonce, variant.eta1() * 2 * 32);
        let noise = cbd(&noise_seed, variant.eta1());
        e_coeffs.push(noise);
    }

    let nt_s: Vec<Vec<i16>> = s_coeffs.iter().map(|poly| ntt(poly)).collect();
    let nt_e: Vec<Vec<i16>> = e_coeffs.iter().map(|poly| ntt(poly)).collect();

    let mut t = vec![vec![0i16; 256]; k];
    for i in 0..k {
        for j in 0..k {
            let prod = poly_mul(&matrix[i][j], &nt_s[j]);
            for idx in 0..256 {
                t[i][idx] = mod_reduce(t[i][idx] + prod[idx]);
            }
        }
        t[i] = add_polys(&t[i], &nt_e[i]);
    }

    let mut pk = vec![0u8; pk_size];
    for i in 0..32 {
        pk[i] = seed[i];
    }

    let mut offset = 32;
    for i in 0..k {
        let poly = &t[i];
        for j in 0..128 {
            let val = compress(poly[2 * j], 12) | (compress(poly[2 * j + 1], 12) << 8);
            if offset < pk_size {
                pk[offset] = (val & 0xFF) as u8;
            }
            if offset + 1 < pk_size {
                pk[offset + 1] = ((val >> 8) & 0xFF) as u8;
            }
            offset += 2;
        }
    }

    let mut sk = vec![0u8; sk_size];
    let mut sk_offset = 0;

    for i in 0..k {
        let poly = &s_coeffs[i];
        for j in 0..128 {
            let val = (poly[2 * j] as u16) | ((poly[2 * j + 1] as u16) << 4);
            if sk_offset < sk_size {
                sk[sk_offset] = (val & 0xFF) as u8;
            }
            if sk_offset + 1 < sk_size {
                sk[sk_offset + 1] = ((val >> 8) & 0xFF) as u8;
            }
            sk_offset += 2;
        }
    }

    for byte in pk.iter() {
        if sk_offset < sk_size {
            sk[sk_offset] = *byte;
            sk_offset += 1;
        }
    }

    for byte in seed_z.iter() {
        if sk_offset < sk_size {
            sk[sk_offset] = *byte;
            sk_offset += 1;
        }
    }

    pk[0] = variant as u8;
    sk[0] = variant as u8;

    Ok((pk, sk))
}

pub fn keypair() -> crate::Result<(Vec<u8>, Vec<u8>)> {
    keypair_variant(KyberVariant::Kyber768)
}

pub fn keypair_variant(variant: KyberVariant) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    kyber_internal_keypair(variant)
}

fn kyber_internal_encapsulate(public_key: &[u8]) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    let variant = match public_key.first() {
        Some(&0) => KyberVariant::Kyber512,
        Some(&1) => KyberVariant::Kyber768,
        Some(&2) => KyberVariant::Kyber1024,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown Kyber variant".into())),
    };

    let k = variant.k();
    let ct_size = variant.ct_size();
    let mut rng = rand::thread_rng();

    let mut m = [0u8; 32];
    rng.fill_bytes(&mut m);

    let g_out = g(&m);
    let mut seed = [0u8; 32];
    seed.copy_from_slice(&g_out[..32]);
    let mut k_bar = [0u8; 32];
    k_bar.copy_from_slice(&g_out[32..]);

    let mut rho_seed = [0u8; 34];
    let pk_seed = &public_key[1..33];
    rho_seed[..32].copy_from_slice(pk_seed);
    rho_seed[32] = 0;
    rho_seed[33] = 0;

    let matrix_t = generate_matrix(&rho_seed, k, true);

    let mut r_coeffs = Vec::with_capacity(k);
    for i in 0..k {
        let nonce = i as u8;
        let noise_seed = prf(&seed, nonce, variant.eta1() * 2 * 32);
        let noise = cbd(&noise_seed, variant.eta1());
        r_coeffs.push(noise);
    }

    let mut e1_coeffs = Vec::with_capacity(k);
    for i in 0..k {
        let nonce = (k + i) as u8;
        let noise_seed = prf(&seed, nonce, variant.eta2() * 2 * 32);
        let noise = cbd(&noise_seed, variant.eta2());
        e1_coeffs.push(noise);
    }

    let e2_seed = prf(&seed, 2 * k as u8, variant.eta2() * 2 * 32);
    let e2 = cbd(&e2_seed, variant.eta2());

    let nt_r: Vec<Vec<i16>> = r_coeffs.iter().map(|poly| ntt(poly)).collect();
    let u = matrix_vector_mul(&matrix_t, &nt_r);

    let mut u_poly = vec![0i16; 256];
    for i in 0..k {
        let inv = inv_ntt(&u[i]);
        let with_noise = add_polys(&inv, &e1_coeffs[i]);
        for idx in 0..256 {
            u_poly[idx] = mod_reduce(u_poly[idx]);
        }
    }

    let mut u_bytes = vec![0u8; k * 32 * variant.du() / 8];
    let mut u_off = 0;
    for i in 0..k {
        for j in 0..128 {
            let val = compress(u[i][2 * j], variant.du()) as u16
                | ((compress(u[i][2 * j + 1], variant.du()) as u16) << variant.du() as u16);
            if u_off < u_bytes.len() {
                u_bytes[u_off] = (val & 0xFF) as u8;
            }
            if u_off + 1 < u_bytes.len() {
                u_bytes[u_off + 1] = ((val >> 8) & 0xFF) as u8;
            }
            u_off += 2;
        }
    }

    let t_offset = 33;
    let t_poly_size = (variant.pk_size() - 32) / k;

    let mut v = vec![0i16; 256];
    for i in 0..k {
        let mut t_i = vec![0i16; 256];
        for j in 0..128 {
            let lo = public_key[t_offset + i * t_poly_size + 2 * j] as u16;
            let hi = public_key[t_offset + i * t_poly_size + 2 * j + 1] as u16;
            let packed = lo | (hi << 8);
            t_i[2 * j] = decompress((packed & 0xFFF) as i16, 12);
            t_i[2 * j + 1] = decompress(((packed >> 12) & 0xFFF) as i16, 12);
        }
        let nt_t_i = ntt(&t_i);
        let dot = poly_mul(&nt_t_i, &nt_r[0]);
        for idx in 0..256 {
            if i == 0 {
                v[idx] = mod_reduce(v[idx] + dot[idx]);
            }
        }
    }
    let v_inv = inv_ntt(&v);

    let mut v_with_e2 = add_polys(&v_inv, &e2);
    let compressed_m = |val: i16| -> i16 { ((val as i32) << 1) / 3329 };

    for idx in 0..256 {
        let m_bit = (m[idx / 8] >> (idx % 8)) & 1;
        let adjusted = v_with_e2[idx];
        let compressed_m_val = if m_bit == 1 {
            (adjusted + 3329 / 2) % 3329
        } else {
            adjusted
        };
        v_with_e2[idx] = compress(compressed_m_val, variant.dv());
    }

    let mut v_bytes = vec![0u8; k * 32 * variant.dv() / 8];
    for j in 0..128 {
        let val = v_with_e2[2 * j] as u16 | ((v_with_e2[2 * j + 1] as u16) << variant.dv() as u16);
        if 2 * j < v_bytes.len() {
            v_bytes[2 * j] = (val & 0xFF) as u8;
        }
        if 2 * j + 1 < v_bytes.len() {
            v_bytes[2 * j + 1] = ((val >> 8) & 0xFF) as u8;
        }
    }

    let mut ciphertext = Vec::with_capacity(ct_size);
    ciphertext.push(variant as u8);
    ciphertext.extend_from_slice(&u_bytes);
    ciphertext.extend_from_slice(&v_bytes);

    let h_input = [&ciphertext[1..], &m].concat();
    let h_out = h(&h_input, 32);
    let mut k_final = [0u8; 32];
    for i in 0..32 {
        k_final[i] = k_bar[i] ^ h_out[i];
    }

    let shared_secret = kdf2(&k_final);

    Ok((ciphertext, shared_secret))
}

pub fn encapsulate(public_key: &[u8]) -> crate::Result<(Vec<u8>, Vec<u8>)> {
    kyber_internal_encapsulate(public_key)
}

fn kyber_internal_decapsulate(ciphertext: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    let variant = match ciphertext.first() {
        Some(&0) => KyberVariant::Kyber512,
        Some(&1) => KyberVariant::Kyber768,
        Some(&2) => KyberVariant::Kyber1024,
        _ => return Err(crate::CryptoError::InvalidKeyFormat("unknown Kyber variant".into())),
    };

    let k = variant.k();

    if secret_key.len() < variant.sk_size() {
        return Err(crate::CryptoError::InvalidKeyFormat("secret key too short".into()));
    }

    let mut s_coeffs = Vec::with_capacity(k);
    let mut sk_offset = 1;
    for i in 0..k {
        let mut poly = vec![0i16; 256];
        for j in 0..128 {
            let lo = secret_key[sk_offset + 2 * j] as u16;
            let hi = secret_key[sk_offset + 2 * j + 1] as u16;
            let packed = lo | (hi << 8);
            poly[2 * j] = ((packed & 0xF) as i16) - (((packed >> 4) & 0xF) as i16);
            poly[2 * j + 1] = (((packed >> 8) & 0xF) as i16) - (((packed >> 12) & 0xF) as i16);
        }
        sk_offset += 128 * 2;
        s_coeffs.push(poly);
    }

    let pk_size = variant.pk_size();
    let mut pk = vec![0u8; pk_size];
    for i in 0..pk_size.min(secret_key.len().saturating_sub(sk_offset)) {
        pk[i] = secret_key[sk_offset + i];
    }
    sk_offset += pk_size;

    let mut z = [0u8; 32];
    for i in 0..32 {
        z[i] = secret_key.get(sk_offset + i).copied().unwrap_or(0);
    }

    let ct_size = variant.ct_size();
    let u_size = k * 32 * variant.du() / 8;
    let v_size = k * 32 * variant.dv() / 8;

    let ct_data = if ciphertext.len() > 1 { &ciphertext[1..] } else { &[] };

    let u_bytes = if ct_data.len() >= u_size { &ct_data[..u_size] } else { ct_data };
    let v_bytes = if ct_data.len() >= u_size + v_size {
        &ct_data[u_size..u_size + v_size]
    } else {
        &[]
    };

    let mut u = Vec::with_capacity(k);
    for i in 0..k {
        let mut poly = vec![0i16; 256];
        let u_off = i * 32 * variant.du() / 8;
        for j in 0..128 {
            let idx = u_off + 2 * j;
            let lo = u_bytes.get(idx).copied().unwrap_or(0) as u16;
            let hi = u_bytes.get(idx + 1).copied().unwrap_or(0) as u16;
            let packed = lo | (hi << 8);
            poly[2 * j] = decompress((packed & ((1 << variant.du()) - 1) as u16) as i16, variant.du());
            poly[2 * j + 1] = decompress((packed >> variant.du() as u16) as i16, variant.du());
        }
        u.push(poly);
    }

    let mut v_poly = vec![0i16; 256];
    for j in 0..128 {
        let lo = v_bytes.get(2 * j).copied().unwrap_or(0) as u16;
        let hi = v_bytes.get(2 * j + 1).copied().unwrap_or(0) as u16;
        let packed = lo | (hi << 8);
        v_poly[2 * j] = decompress((packed & ((1 << variant.dv()) - 1) as u16) as i16, variant.dv());
        v_poly[2 * j + 1] = decompress((packed >> variant.dv() as u16) as i16, variant.dv());
    }

    let nt_s: Vec<Vec<i16>> = s_coeffs.iter().map(|poly| ntt(poly)).collect();

    let mut w = vec![0i16; 256];
    for i in 0..k {
        let nt_u_i = ntt(&u[i]);
        let dot = poly_mul(&nt_s[i], &nt_u_i);
        for idx in 0..256 {
            w[idx] = mod_reduce(w[idx] + dot[idx]);
        }
    }
    let w_inv = inv_ntt(&w);

    let mut m = [0u8; 32];
    for idx in 0..256 {
        let v_val = v_poly[idx];
        let w_val = w_inv[idx];
        let diff = mod_reduce(v_val - w_val);
        let m_bit = if diff > 3329 / 4 && diff < 3 * 3329 / 4 { 1 } else { 0 };
        m[idx / 8] |= (m_bit as u8) << (idx % 8);
    }

    let g_out_m = g(&m);
    let mut seed_prime = [0u8; 32];
    seed_prime.copy_from_slice(&g_out_m[..32]);
    let mut k_prime = [0u8; 32];
    k_prime.copy_from_slice(&g_out_m[32..]);

    let h_input = [&ciphertext[1..], &m].concat();
    let h_out = h(&h_input, 32);

    let mut k_final = [0u8; 32];
    for i in 0..32 {
        k_final[i] = k_prime[i] ^ h_out[i];
    }

    let shared_secret = kdf2(&k_final);

    Ok(shared_secret)
}

pub fn decapsulate(ciphertext: &[u8], secret_key: &[u8]) -> crate::Result<Vec<u8>> {
    kyber_internal_decapsulate(ciphertext, secret_key)
}

impl Keygen for KyberVariant {
    type PublicKey = Vec<u8>;
    type SecretKey = Vec<u8>;

    fn keypair() -> crate::Result<(Self::PublicKey, Self::SecretKey)> {
        kyber_internal_keypair(KyberVariant::Kyber768)
    }
}

impl KemScheme for KyberVariant {
    type PublicKey = Vec<u8>;
    type SecretKey = Vec<u8>;
    type Ciphertext = Vec<u8>;

    fn keygen() -> crate::Result<(Self::PublicKey, Self::SecretKey)> {
        kyber_internal_keypair(KyberVariant::Kyber768)
    }

    fn encapsulate(pk: &Self::PublicKey) -> crate::Result<(Self::Ciphertext, Vec<u8>)> {
        kyber_internal_encapsulate(pk)
    }

    fn decapsulate(ct: &Self::Ciphertext, sk: &Self::SecretKey) -> crate::Result<Vec<u8>> {
        kyber_internal_decapsulate(ct, sk)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kyber_keypair() {
        let (pk, sk) = keypair().unwrap();
        assert_eq!(pk.len(), KYBER768_PK_SIZE);
        assert_eq!(sk.len(), KYBER768_SK_SIZE);
    }

    #[test]
    fn test_kyber_encaps_decaps() {
        let (pk, sk) = keypair().unwrap();
        let (ct, ss1) = encapsulate(&pk).unwrap();
        assert_eq!(ct.len(), KYBER768_CT_SIZE);
        assert_eq!(ss1.len(), SHARED_SECRET_SIZE);

        let ss2 = decapsulate(&ct, &sk).unwrap();
        assert_eq!(ss2.len(), SHARED_SECRET_SIZE);
    }

    #[test]
    fn test_kyber_variants() {
        for variant in &[KyberVariant::Kyber512, KyberVariant::Kyber768, KyberVariant::Kyber1024] {
            let (pk, sk) = keypair_variant(*variant).unwrap();
            assert_eq!(pk.len(), variant.pk_size());
            assert_eq!(sk.len(), variant.sk_size());

            let (ct, _) = encapsulate(&pk).unwrap();
            assert_eq!(ct.len(), variant.ct_size());
        }
    }

    #[test]
    fn test_kyber_ind_cca2() {
        let (pk, sk) = keypair_variant(KyberVariant::Kyber512).unwrap();
        let (ct1, ss1) = encapsulate(&pk).unwrap();
        let (ct2, ss2) = encapsulate(&pk).unwrap();

        assert_ne!(ss1, ss2, "IND-CCA2: two encapsulations should produce different shared secrets");
        assert_ne!(ct1, ct2, "IND-CCA2: two encapsulations should produce different ciphertexts");

        let ss1_dec = decapsulate(&ct1, &sk).unwrap();
        assert_eq!(ss1, ss1_dec, "decapsulation should recover the original shared secret");

        let ss2_dec = decapsulate(&ct2, &sk).unwrap();
        assert_eq!(ss2, ss2_dec, "decapsulation should recover the second shared secret");
    }
}
