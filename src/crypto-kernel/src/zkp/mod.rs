pub mod aggregator;
pub mod merkle_proof;
pub mod noir;
pub mod risc_zero;

use serde::{Deserialize, Serialize};

pub type ZkpResult<T> = Result<T, ZkpError>;

#[derive(Debug, thiserror::Error)]
pub enum ZkpError {
    #[error("proof generation failed: {0}")]
    GenerationFailed(String),

    #[error("proof verification failed: {0}")]
    VerificationFailed(String),

    #[error("unsupported proof system: {0}")]
    UnsupportedSystem(String),

    #[error("invalid proof data: {0}")]
    InvalidProofData(String),

    #[error("circuit compilation failed: {0}")]
    CircuitCompilationFailed(String),

    #[error("witness generation failed: {0}")]
    WitnessGenerationFailed(String),

    #[error("recursive proof composition failed: {0}")]
    RecursiveCompositionFailed(String),

    #[error("batch proof aggregation failed: {0}")]
    AggregationFailed(String),

    #[error("merkle proof integration failed: {0}")]
    MerkleProofFailed(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ProofSystem {
    Noir,
    RiscZero,
    Groth16,
    Plonk,
}

impl ProofSystem {
    pub fn name(&self) -> &'static str {
        match self {
            ProofSystem::Noir => "Noir",
            ProofSystem::RiscZero => "RISC Zero",
            ProofSystem::Groth16 => "Groth16",
            ProofSystem::Plonk => "PLONK",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerificationResult {
    pub verified: bool,
    pub proof_system: ProofSystem,
    pub verification_time_ms: u64,
    pub public_inputs_checked: usize,
}

impl VerificationResult {
    pub fn new(verified: bool, proof_system: ProofSystem) -> Self {
        VerificationResult {
            verified,
            proof_system,
            verification_time_ms: 0,
            public_inputs_checked: 0,
        }
    }

    pub fn with_verification_time(mut self, ms: u64) -> Self {
        self.verification_time_ms = ms;
        self
    }

    pub fn with_inputs_checked(mut self, count: usize) -> Self {
        self.public_inputs_checked = count;
        self
    }
}

pub fn verify_proof(proof: &ZkpProof) -> ZkpResult<VerificationResult> {
    let start = std::time::Instant::now();

    match proof.proof_system {
        ProofSystem::Noir => {
            let vk = noir::NoirVerifyingKey {
                circuit_hash: [0u8; 32],
                verifying_data: Vec::new(),
            };
            let valid = noir::NoirBackend::verify_proof(&vk, proof, &[])?;
            let elapsed = start.elapsed();
            Ok(VerificationResult::new(valid, ProofSystem::Noir)
                .with_verification_time(elapsed.as_millis() as u64)
                .with_inputs_checked(proof.public_inputs.len()))
        }
        ProofSystem::RiscZero => {
            let vk = risc_zero::RiscZeroVerifyingKey {
                image_id: risc_zero::RiscZeroImageId::new("default", &[0u8; 32]),
                verifying_data: Vec::new(),
            };
            let valid = risc_zero::RiscZeroBackend::verify_proof(&vk, proof, &[])?;
            let elapsed = start.elapsed();
            Ok(VerificationResult::new(valid, ProofSystem::RiscZero)
                .with_verification_time(elapsed.as_millis() as u64)
                .with_inputs_checked(proof.public_inputs.len()))
        }
        ProofSystem::Groth16 => Err(ZkpError::UnsupportedSystem(
            "Groth16 verification not yet implemented".into(),
        )),
        ProofSystem::Plonk => Err(ZkpError::UnsupportedSystem(
            "PLONK verification not yet implemented".into(),
        )),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProofType {
    Single(Vec<u8>),
    Batch(Vec<Vec<u8>>),
    Recursive(Vec<u8>, Vec<u8>),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ZkpProof {
    pub proof_system: ProofSystem,
    pub proof_type: ProofType,
    pub public_inputs: Vec<Vec<u8>>,
    pub circuit_id: Option<String>,
    pub metadata: ZkpMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ZkpMetadata {
    pub created_at: u64,
    pub proving_time_ms: Option<u64>,
    pub proof_size_bytes: usize,
    pub security_level_bits: usize,
}

impl ZkpProof {
    pub fn new(
        proof_system: ProofSystem,
        proof_type: ProofType,
        public_inputs: Vec<Vec<u8>>,
    ) -> Self {
        let proof_size = match &proof_type {
            ProofType::Single(data) => data.len(),
            ProofType::Batch(data_vec) => data_vec.iter().map(|d| d.len()).sum(),
            ProofType::Recursive(data, _) => data.len(),
        };

        ZkpProof {
            proof_system,
            proof_type,
            public_inputs,
            circuit_id: None,
            metadata: ZkpMetadata {
                created_at: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs(),
                proving_time_ms: None,
                proof_size_bytes: proof_size,
                security_level_bits: 128,
            },
        }
    }

    pub fn with_circuit_id(mut self, circuit_id: impl Into<String>) -> Self {
        self.circuit_id = Some(circuit_id.into());
        self
    }

    pub fn with_security_level(mut self, bits: usize) -> Self {
        self.metadata.security_level_bits = bits;
        self
    }

    pub fn with_proving_time(mut self, ms: u64) -> Self {
        self.metadata.proving_time_ms = Some(ms);
        self
    }
}

pub trait ProofSystemTrait {
    type ProvingKey;
    type VerifyingKey;
    type PublicInputs;

    fn generate_proof(
        pk: &Self::ProvingKey,
        public_inputs: &Self::PublicInputs,
        private_inputs: &[u8],
    ) -> ZkpResult<ZkpProof>;

    fn verify_proof(
        vk: &Self::VerifyingKey,
        proof: &ZkpProof,
        public_inputs: &Self::PublicInputs,
    ) -> ZkpResult<bool>;

    fn setup() -> ZkpResult<(Self::ProvingKey, Self::VerifyingKey)>;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReceiptCircuitWitness {
    pub signal_hash: [u8; 32],
    pub timestamp: u64,
    pub min_timestamp: u64,
    pub max_timestamp: u64,
    pub station_id: [u8; 16],
    pub capabilities: Vec<u8>,
    pub merkle_root: [u8; 32],
    pub merkle_proof: Vec<Vec<u8>>,
    pub leaf_index: usize,
    pub signal_strength: i32,
    pub frequency_mhz: f64,
    pub snr_db: f64,
    pub location_lat: f64,
    pub location_lon: f64,
    pub proximity_threshold_km: f64,
}

impl ReceiptCircuitWitness {
    pub fn to_public_inputs(&self) -> Vec<Vec<u8>> {
        vec![
            self.signal_hash.to_vec(),
            self.timestamp.to_le_bytes().to_vec(),
            self.merkle_root.to_vec(),
            self.station_id.to_vec(),
        ]
    }

    pub fn to_private_inputs(&self) -> Vec<u8> {
        let mut data = Vec::new();
        data.extend_from_slice(&self.min_timestamp.to_le_bytes());
        data.extend_from_slice(&self.max_timestamp.to_le_bytes());
        data.extend_from_slice(&self.capabilities);
        for sibling in &self.merkle_proof {
            data.extend_from_slice(sibling);
        }
        data.extend_from_slice(&self.leaf_index.to_le_bytes());
        data.extend_from_slice(&self.signal_strength.to_le_bytes());
        data.extend_from_slice(&self.frequency_mhz.to_le_bytes());
        data.extend_from_slice(&self.snr_db.to_le_bytes());
        data.extend_from_slice(&self.location_lat.to_le_bytes());
        data.extend_from_slice(&self.location_lon.to_le_bytes());
        data.extend_from_slice(&self.proximity_threshold_km.to_le_bytes());
        data
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zkp_proof_creation() {
        let proof = ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Single(vec![1, 2, 3, 4]),
            vec![b"public_input".to_vec()],
        );
        assert_eq!(proof.proof_system, ProofSystem::Noir);
        assert!(proof.circuit_id.is_none());
    }

    #[test]
    fn test_proof_system_names() {
        assert_eq!(ProofSystem::Noir.name(), "Noir");
        assert_eq!(ProofSystem::RiscZero.name(), "RISC Zero");
        assert_eq!(ProofSystem::Groth16.name(), "Groth16");
    }

    #[test]
    fn test_receipt_witness() {
        let witness = ReceiptCircuitWitness {
            signal_hash: [0u8; 32],
            timestamp: 1718000000,
            min_timestamp: 1717000000,
            max_timestamp: 1719000000,
            station_id: [0u8; 16],
            capabilities: vec![1, 2, 3],
            merkle_root: [0u8; 32],
            merkle_proof: vec![vec![0u8; 32]],
            leaf_index: 0,
            signal_strength: -70,
            frequency_mhz: 2400.0,
            snr_db: 15.5,
            location_lat: 37.7749,
            location_lon: -122.4194,
            proximity_threshold_km: 50.0,
        };
        let pub_inputs = witness.to_public_inputs();
        assert_eq!(pub_inputs.len(), 4);
        let priv_inputs = witness.to_private_inputs();
        assert!(!priv_inputs.is_empty());
    }

    #[test]
    fn test_verification_result() {
        let result = VerificationResult::new(true, ProofSystem::Noir)
            .with_verification_time(42)
            .with_inputs_checked(4);
        assert!(result.verified);
        assert_eq!(result.verification_time_ms, 42);
        assert_eq!(result.public_inputs_checked, 4);
    }

    #[test]
    fn test_verify_proof_dispatcher() {
        let proof = ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Single(vec![0u8; 64]),
            vec![],
        );
        let result = verify_proof(&proof);
        assert!(result.is_ok());
        let vr = result.unwrap();
        assert_eq!(vr.proof_system, ProofSystem::Noir);
    }
}
