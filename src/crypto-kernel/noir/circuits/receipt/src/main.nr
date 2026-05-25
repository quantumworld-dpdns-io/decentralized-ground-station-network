mod types;
mod proof;

use crate::types;
use crate::proof;

pub fn verify_receipt(
    signal_hash: Field,
    station_id: Field,
    timestamp: Field,
    merkle_root: Field,
    merkle_proof: [Field; 8],
) -> pub bool {
    let timestamp_valid: bool = (timestamp as u64) > 0;

    let merkle_valid: bool = proof::verify_merkle_proof(signal_hash, merkle_root, merkle_proof);

    let station_valid: bool = station_id != 0;

    let result: bool = timestamp_valid & merkle_valid & station_valid;

    result
}

#[test]
fn test_valid_receipt() {
    let signal_hash: Field = 0x123456789abcdef;
    let station_id: Field = 0xaabbccdd;
    let timestamp: Field = 1718000000;
    let merkle_root: Field = 0xdeadbeef;
    let merkle_proof: [Field; 8] = [1, 2, 3, 4, 5, 6, 7, 8];

    let result = verify_receipt(signal_hash, station_id, timestamp, merkle_root, merkle_proof);
    assert(result);
}

#[test]
fn test_invalid_timestamp() {
    let result = verify_receipt(1, 2, 0, 3, [0; 8]);
    assert(!result);
}

#[test]
fn test_invalid_station() {
    let result = verify_receipt(1, 0, 1718000000, 3, [0; 8]);
    assert(!result);
}
