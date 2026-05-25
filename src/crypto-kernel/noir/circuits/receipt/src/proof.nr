use crate::types;

fn compute_merkle_root(leaf: [u8; 32], siblings: [u8; 256], leaf_index: u32, path_mask: [u8; 8]) -> [u8; 32] {
    let mut current = leaf;
    let mut idx: u32 = leaf_index;

    for i in 0..8 {
        let sibling_offset = i * 32;
        let mut sibling: [u8; 32] = [0; 32];
        for j in 0..32 {
            sibling[j] = siblings[sibling_offset + j];
        }

        let is_right: bool = (path_mask[i / 8] >> (i % 8)) & 1 == 1;

        let mut hash_input: [u8; 65] = [0; 65];
        if is_right {
            hash_input[0] = 0x01;
            for j in 0..32 {
                hash_input[1 + j] = current[j];
            }
            for j in 0..32 {
                hash_input[33 + j] = sibling[j];
            }
        } else {
            hash_input[0] = 0x01;
            for j in 0..32 {
                hash_input[1 + j] = sibling[j];
            }
            for j in 0..32 {
                hash_input[33 + j] = current[j];
            }
        }

        current = std::hash::sha256(hash_input);
        idx = idx / 2;
    }

    current
}

fn verify_merkle_inclusion(
    merkle_root: [u8; 32],
    leaf: [u8; 32],
    siblings: [u8; 256],
    leaf_index: u32,
    path_mask: [u8; 8],
) -> bool {
    let computed_root = compute_merkle_root(leaf, siblings, leaf_index, path_mask);
    computed_root == merkle_root
}

fn verify_location_proximity(
    station_lat: i64,
    station_lon: i64,
    expected_lat: i64,
    expected_lon: i64,
    threshold_km: u64,
) -> bool {
    let lat_diff: i64 = station_lat - expected_lat;
    let lon_diff: i64 = station_lon - expected_lon;

    let lat_diff_abs: u64 = if lat_diff < 0 { -lat_diff as u64 } else { lat_diff as u64 };
    let lon_diff_abs: u64 = if lon_diff < 0 { -lon_diff as u64 } else { lon_diff as u64 };

    let approx_km_per_degree_lat: u64 = 111;
    let approx_km_per_degree_lon: u64 = 85;

    let lat_km: u64 = lat_diff_abs * approx_km_per_lat;
    let lon_km: u64 = lon_diff_abs * approx_km_per_lon;

    let distance_sq: u64 = lat_km * lat_km + lon_km * lon_km;
    let threshold_sq: u64 = threshold_km * threshold_km;

    distance_sq <= threshold_sq
}

fn verify_signal_quality(
    signal_strength: i64,
    snr_db: u64,
    min_signal_strength: i64,
    min_snr_db: u64,
) -> bool {
    let strength_ok = signal_strength >= min_signal_strength;
    let snr_ok = snr_db >= min_snr_db;
    strength_ok & snr_ok
}

fn verify_timestamp_range(
    timestamp: u64,
    min_timestamp: u64,
    max_timestamp: u64,
) -> bool {
    (timestamp >= min_timestamp) & (timestamp <= max_timestamp)
}

fn verify_capabilities(
    capabilities_bitmask: [u8; 8],
    required_band: u8,
    required_modulation: [u8; 4],
) -> bool {
    let band_byte: u8 = required_band / 8;
    let band_bit: u8 = required_band % 8;

    if band_byte >= 8 {
        return false;
    }

    let has_band: bool = (capabilities_bitmask[band_byte as u64] >> band_bit) & 1 == 1;
    has_band
}
