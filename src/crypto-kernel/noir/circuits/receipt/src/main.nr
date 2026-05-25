mod types;
mod proof;

use crate::types;
use crate::proof;

fn main(
    signal_hash: [u8; 32],
    timestamp: u64,
    min_timestamp: u64,
    max_timestamp: u64,
    merkle_root: [u8; 32],
    station_id: [u8; 16],

    leaf_index: u32,
    merkle_siblings: [u8; 256],
    merkle_path_mask: [u8; 8],

    signal_strength: i64,
    snr_db: u64,
    frequency_mhz: u64,

    station_lat: i64,
    station_lon: i64,
    proximity_threshold_km: u64,

    capabilities_bitmask: [u8; 8],
    required_band: u8,
    min_signal_strength: i64,
    min_snr_db: u64,

    expected_lat: i64,
    expected_lon: i64,
) -> pub [u8; 32] {
    let timestamp_valid = proof::verify_timestamp_range(timestamp, min_timestamp, max_timestamp);

    let location_valid = proof::verify_location_proximity(
        station_lat, station_lon,
        expected_lat, expected_lon,
        proximity_threshold_km,
    );

    let signal_quality_valid = proof::verify_signal_quality(
        signal_strength, snr_db,
        min_signal_strength, min_snr_db,
    );

    let mut leaf: [u8; 32] = [0; 32];
    for i in 0..32 {
        leaf[i] = signal_hash[i];
    }
    let merkle_valid = proof::verify_merkle_inclusion(
        merkle_root, leaf, merkle_siblings, leaf_index, merkle_path_mask,
    );

    let capabilities_valid = proof::verify_capabilities(
        capabilities_bitmask, required_band, [0; 4],
    );

    let overall_valid: bool = timestamp_valid & location_valid & signal_quality_valid & merkle_valid & capabilities_valid;

    let mut receipt_id: [u8; 32] = [0; 32];
    if overall_valid {
        let mut hasher_input: [u8; 96] = [0; 96];
        for i in 0..32 {
            hasher_input[i] = signal_hash[i];
        }
        let ts_bytes: [u8; 8] = timestamp.to_be_bytes();
        for i in 0..8 {
            hasher_input[32 + i] = ts_bytes[i];
        }
        for i in 0..16 {
            hasher_input[40 + i] = station_id[i];
        }
        for i in 0..32 {
            hasher_input[56 + i] = merkle_root[i];
        }

        receipt_id = std::hash::sha256(hasher_input);
    }

    receipt_id
}

#[test]
fn test_valid_receipt() {
    let signal_hash: [u8; 32] = [1; 32];
    let timestamp: u64 = 1718000000;
    let min_timestamp: u64 = 1717000000;
    let max_timestamp: u64 = 1719000000;
    let merkle_root: [u8; 32] = [2; 32];
    let station_id: [u8; 16] = [3; 16];

    let leaf_index: u32 = 0;
    let merkle_siblings: [u8; 256] = [4; 256];
    let merkle_path_mask: [u8; 8] = [0; 8];

    let signal_strength: i64 = -70;
    let snr_db: u64 = 20;
    let frequency_mhz: u64 = 2400;

    let station_lat: i64 = 377749;
    let station_lon: i64 = -1224194;
    let proximity_threshold_km: u64 = 50;

    let capabilities_bitmask: [u8; 8] = [0b00000001, 0, 0, 0, 0, 0, 0, 0];
    let required_band: u8 = 0;
    let min_signal_strength: i64 = -100;
    let min_snr_db: u64 = 10;

    let expected_lat: i64 = 377749;
    let expected_lon: i64 = -1224194;

    let receipt_id = main(
        signal_hash,
        timestamp,
        min_timestamp,
        max_timestamp,
        merkle_root,
        station_id,
        leaf_index,
        merkle_siblings,
        merkle_path_mask,
        signal_strength,
        snr_db,
        frequency_mhz,
        station_lat,
        station_lon,
        proximity_threshold_km,
        capabilities_bitmask,
        required_band,
        min_signal_strength,
        min_snr_db,
        expected_lat,
        expected_lon,
    );

    assert(receipt_id != [0; 32]);
}
