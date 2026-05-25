struct SignalMetadata {
    frequency_mhz: u64,
    signal_strength: i64,
    snr_db: u64,
    bandwidth_khz: u64,
    modulation_type: [u8; 16],
}

struct StationIdentity {
    station_id: [u8; 16],
    operator_id: [u8; 16],
    hardware_version: [u8; 8],
    firmware_version: [u8; 8],
}

struct Location {
    latitude: i64,
    longitude: i64,
    altitude_m: i64,
}

struct StationCapabilities {
    frequency_bands: [u8; 8],
    max_power_dbm: i64,
    antenna_type: [u8; 16],
    supported_modulations: [u8; 16],
    is_portable: bool,
}

struct ReceiptPublic {
    signal_hash: [u8; 32],
    timestamp: u64,
    min_timestamp: u64,
    max_timestamp: u64,
    merkle_root: [u8; 32],
    station_id: [u8; 16],
}

struct ReceiptPrivate {
    leaf_index: u32,
    merkle_siblings: [u8; 256],
    signal_metadata: SignalMetadata,
    station_identity: StationIdentity,
    location: Location,
    capabilities: StationCapabilities,
    proximity_threshold_km: u64,
    operator_signature_r: [u8; 32],
    operator_signature_s: [u8; 32],
}

struct MerkleProof {
    leaf: [u8; 32],
    leaf_index: u32,
    siblings: [u8; 256],
    path_mask: [u8; 8],
}

struct ProofOutput {
    valid_timestamp: bool,
    valid_location: bool,
    valid_capabilities: bool,
    merkle_included: bool,
    signal_hash_match: bool,
    overall_valid: bool,
    receipt_id: [u8; 32],
}
