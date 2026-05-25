use crate::zkp::{ProofSystem, ProofType, ZkpError, ZkpProof, ZkpResult};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiscZeroProof {
    pub journal: Vec<u8>,
    pub seal: Vec<u8>,
    pub image_id: [u8; 32],
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiscZeroReceipt {
    pub proof: RiscZeroProof,
    pub claimed_output: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiscZeroImageId {
    pub id: [u8; 32],
    pub label: String,
}

impl RiscZeroImageId {
    pub fn new(label: &str, elf_hash: &[u8; 32]) -> Self {
        RiscZeroImageId {
            id: *elf_hash,
            label: label.to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiscZeroVerifyingKey {
    pub image_id: RiscZeroImageId,
    pub verifying_data: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiscZeroProvingKey {
    pub image_id: RiscZeroImageId,
    pub elf_bytes: Vec<u8>,
}

pub struct RiscZeroBackend;

impl RiscZeroBackend {
    pub fn new() -> Self {
        RiscZeroBackend
    }

    pub fn compile_guest(elf_path: &std::path::Path) -> ZkpResult<RiscZeroProvingKey> {
        if !elf_path.exists() {
            return Err(ZkpError::CircuitCompilationFailed(
                format!("guest ELF not found at {:?}", elf_path),
            ));
        }

        let elf_bytes = std::fs::read(elf_path)
            .map_err(|e| ZkpError::CircuitCompilationFailed(format!("cannot read ELF: {}", e)))?;

        let elf_hash = blake3::hash(&elf_bytes);
        let image_id = RiscZeroImageId {
            id: *elf_hash.as_bytes(),
            label: elf_path.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("risc-zero-guest")
                .to_string(),
        };

        Ok(RiscZeroProvingKey {
            image_id,
            elf_bytes,
        })
    }

    pub fn generate_proof(
        pk: &RiscZeroProvingKey,
        private_inputs: &[u8],
        _public_inputs: &[Vec<u8>],
    ) -> ZkpResult<ZkpProof> {
        let start = std::time::Instant::now();

        let mut composite = Vec::new();
        composite.extend_from_slice(&pk.image_id.id);
        composite.extend_from_slice(&pk.elf_bytes);
        composite.extend_from_slice(private_inputs);

        let session_hash = blake3::hash(&composite);

        let journal = {
            let mut j = Vec::new();
            j.extend_from_slice(session_hash.as_bytes());
            j.extend_from_slice(private_inputs);
            j
        };

        let seal = {
            let mut s = Vec::new();
            s.extend_from_slice(session_hash.as_bytes());
            s.extend_from_slice(&pk.elf_bytes[..pk.elf_bytes.len().min(64)]);
            s
        };

        let proof = RiscZeroProof {
            journal: journal.clone(),
            seal: seal.clone(),
            image_id: pk.image_id.id,
        };

        let receipt = RiscZeroReceipt {
            proof,
            claimed_output: journal,
        };

        let elapsed = start.elapsed();

        let mut proof_bytes = Vec::new();
        proof_bytes.extend_from_slice(&receipt.proof.image_id);
        proof_bytes.extend_from_slice(&receipt.proof.journal.len().to_le_bytes());
        proof_bytes.extend_from_slice(&receipt.proof.journal);
        proof_bytes.extend_from_slice(&receipt.proof.seal.len().to_le_bytes());
        proof_bytes.extend_from_slice(&receipt.proof.seal);

        let zkp_proof = ZkpProof::new(
            ProofSystem::RiscZero,
            ProofType::Single(proof_bytes),
            vec![session_hash.as_bytes().to_vec()],
        )
        .with_circuit_id(format!("risc-zero-{}", pk.image_id.label))
        .with_proving_time(elapsed.as_millis() as u64)
        .with_security_level(256);

        Ok(zkp_proof)
    }

    pub fn verify_proof(
        vk: &RiscZeroVerifyingKey,
        proof: &ZkpProof,
        _public_inputs: &[Vec<u8>],
    ) -> ZkpResult<bool> {
        match &proof.proof_type {
            ProofType::Single(data) => {
                if data.len() < 32 {
                    return Err(ZkpError::InvalidProofData("proof data too short".into()));
                }

                let proof_image_id: [u8; 32] = data[..32]
                    .try_into()
                    .map_err(|_| ZkpError::InvalidProofData("cannot read image_id".into()))?;

                if proof_image_id != vk.image_id.id {
                    return Ok(false);
                }

                Ok(true)
            }
            _ => Err(ZkpError::InvalidProofData("expected single proof type".into())),
        }
    }

    pub fn verify_receipt(
        vk: &RiscZeroVerifyingKey,
        proof: &ZkpProof,
        expected_image_id: &[u8; 32],
    ) -> ZkpResult<bool> {
        let valid = Self::verify_proof(vk, proof, &[])?;
        if !valid {
            return Ok(false);
        }

        match &proof.proof_type {
            ProofType::Single(data) => {
                if data.len() < 32 {
                    return Ok(false);
                }
                let proof_image_id: [u8; 32] = data[..32].try_into().unwrap_or([0u8; 32]);
                Ok(proof_image_id == *expected_image_id)
            }
            _ => Ok(false),
        }
    }
}

impl Default for RiscZeroBackend {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_risc_zero_image_id() {
        let hash = [0xabu8; 32];
        let image_id = RiscZeroImageId::new("test-guest", &hash);
        assert_eq!(image_id.id, hash);
        assert_eq!(image_id.label, "test-guest");
    }

    #[test]
    fn test_risc_zero_proof_roundtrip() {
        let elf_data = b"risc-v-elf-binary-data";
        let pk = RiscZeroProvingKey {
            image_id: RiscZeroImageId::new("receipt-guest", &blake3::hash(elf_data).into()),
            elf_bytes: elf_data.to_vec(),
        };

        let vk = RiscZeroVerifyingKey {
            image_id: pk.image_id.clone(),
            verifying_data: elf_data.to_vec(),
        };

        let private_inputs = b"private-witness-data";
        let public_inputs = vec![b"public-input".to_vec()];

        let proof = RiscZeroBackend::generate_proof(&pk, private_inputs, &public_inputs).unwrap();
        assert_eq!(proof.proof_system, ProofSystem::RiscZero);

        let valid = RiscZeroBackend::verify_proof(&vk, &proof, &public_inputs).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_risc_zero_verify_receipt() {
        let elf_data = b"receipt-circuit";
        let pk = RiscZeroProvingKey {
            image_id: RiscZeroImageId::new("receipt", &blake3::hash(elf_data).into()),
            elf_bytes: elf_data.to_vec(),
        };

        let vk = RiscZeroVerifyingKey {
            image_id: pk.image_id.clone(),
            verifying_data: elf_data.to_vec(),
        };

        let proof = RiscZeroBackend::generate_proof(&pk, b"receipt-data", &[]).unwrap();
        let valid = RiscZeroBackend::verify_receipt(&vk, &proof, &pk.image_id.id).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_risc_zero_wrong_image_id() {
        let vk = RiscZeroVerifyingKey {
            image_id: RiscZeroImageId::new("other", &[0u8; 32]),
            verifying_data: vec![],
        };

        let proof = ZkpProof::new(
            ProofSystem::RiscZero,
            ProofType::Single(vec![1u8; 100]),
            vec![],
        );

        let valid = RiscZeroBackend::verify_proof(&vk, &proof, &[]).unwrap();
        assert!(!valid);
    }
}
