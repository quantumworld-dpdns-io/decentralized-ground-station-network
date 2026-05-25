use crate::zkp::{ProofSystem, ProofType, ZkpError, ZkpProof, ZkpResult};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchProof {
    pub proofs: Vec<ZkpProof>,
    pub batch_root: [u8; 32],
    pub proof_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecursiveProof {
    pub inner_proof: Box<ZkpProof>,
    pub outer_proof: ZkpProof,
    pub composition_depth: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AggregationProof {
    pub aggregate_proof: Vec<u8>,
    pub proof_hashes: Vec<[u8; 32]>,
    pub aggregated_public_inputs: Vec<Vec<u8>>,
}

pub struct ProofAggregator;

impl ProofAggregator {
    pub fn new() -> Self {
        ProofAggregator
    }

    pub fn aggregate_batch(proofs: &[ZkpProof]) -> ZkpResult<BatchProof> {
        if proofs.is_empty() {
            return Err(ZkpError::AggregationFailed("empty proof batch".into()));
        }

        if proofs.len() > 1024 {
            return Err(ZkpError::AggregationFailed(
                format!("batch too large: {} proofs (max 1024)", proofs.len()),
            ));
        }

        let first_system = &proofs[0].proof_system;
        for proof in proofs.iter().skip(1) {
            if proof.proof_system != *first_system {
                return Err(ZkpError::AggregationFailed(
                    "all proofs must use the same proof system".into(),
                ));
            }
        }

        let mut hasher = blake3::Hasher::new();
        for proof in proofs {
            let proof_bytes = match &proof.proof_type {
                ProofType::Single(data) => data.clone(),
                ProofType::Batch(data_vec) => data_vec.concat(),
                ProofType::Recursive(data, _) => data.clone(),
            };
            hasher.update(&proof_bytes);
            for input in &proof.public_inputs {
                hasher.update(input);
            }
        }
        let batch_root = *hasher.finalize().as_bytes();

        let aggregated_public_inputs: Vec<Vec<u8>> = proofs.iter()
            .flat_map(|p| p.public_inputs.clone())
            .collect();

        let aggregate_proof = {
            let mut data = Vec::new();
            data.extend_from_slice(&batch_root);
            data.extend_from_slice(&(proofs.len() as u32).to_le_bytes());
            for proof in proofs {
                let proof_bytes = match &proof.proof_type {
                    ProofType::Single(d) => d.clone(),
                    _ => Vec::new(),
                };
                data.extend_from_slice(&(proof_bytes.len() as u32).to_le_bytes());
                data.extend_from_slice(&proof_bytes);
            }
            data
        };

        let _aggregated = AggregationProof {
            aggregate_proof,
            proof_hashes: proofs.iter().map(|p| {
                let h = match &p.proof_type {
                    ProofType::Single(d) => blake3::hash(d),
                    _ => blake3::hash(b""),
                };
                *h.as_bytes()
            }).collect(),
            aggregated_public_inputs,
        };

        let batch = BatchProof {
            proofs: proofs.to_vec(),
            batch_root,
            proof_count: proofs.len(),
        };

        Ok(batch)
    }

    pub fn verify_batch(batch: &BatchProof) -> ZkpResult<bool> {
        if batch.proofs.is_empty() {
            return Ok(false);
        }

        let mut hasher = blake3::Hasher::new();
        for proof in &batch.proofs {
            let proof_bytes = match &proof.proof_type {
                ProofType::Single(data) => data.clone(),
                ProofType::Batch(data_vec) => data_vec.concat(),
                ProofType::Recursive(data, _) => data.clone(),
            };
            hasher.update(&proof_bytes);
            for input in &proof.public_inputs {
                hasher.update(input);
            }
        }
        let computed_root = *hasher.finalize().as_bytes();

        if computed_root != batch.batch_root {
            return Ok(false);
        }

        Ok(true)
    }

    pub fn compose_recursive(inner: ZkpProof, outer_system: ProofSystem) -> ZkpResult<RecursiveProof> {
        let inner_hash = match &inner.proof_type {
            ProofType::Single(data) => blake3::hash(data),
            ProofType::Batch(data_vec) => {
                let mut h = blake3::Hasher::new();
                for d in data_vec {
                    h.update(d);
                }
                h.finalize()
            }
            ProofType::Recursive(data, _) => blake3::hash(data),
        };

        let mut outer_public_inputs = inner.public_inputs.clone();
        outer_public_inputs.push(inner_hash.as_bytes().to_vec());
        outer_public_inputs.push(
            (inner.metadata.security_level_bits as u64).to_le_bytes().to_vec(),
        );

        let mut outer_proof_data = Vec::new();
        outer_proof_data.extend_from_slice(inner_hash.as_bytes());
        outer_proof_data.extend_from_slice(&(inner.metadata.proof_size_bytes as u64).to_le_bytes());
        outer_proof_data.extend_from_slice(&(inner.metadata.security_level_bits as u64).to_le_bytes());

        let outer_proof = ZkpProof::new(
            outer_system,
            ProofType::Recursive(outer_proof_data, inner_hash.as_bytes().to_vec()),
            outer_public_inputs,
        )
        .with_circuit_id("recursive-composition")
        .with_security_level(inner.metadata.security_level_bits + 128)
        .with_proving_time(0);

        Ok(RecursiveProof {
            inner_proof: Box::new(inner),
            outer_proof,
            composition_depth: 1,
        })
    }

    pub fn verify_recursive(recursive: &RecursiveProof) -> ZkpResult<bool> {
        if recursive.composition_depth == 0 {
            return Err(ZkpError::RecursiveCompositionFailed("empty composition depth".into()));
        }

        let inner_hash = match &recursive.inner_proof.proof_type {
            ProofType::Single(data) => blake3::hash(data),
            _ => return Err(ZkpError::RecursiveCompositionFailed(
                "inner proof must be single type".into(),
            )),
        };

        match &recursive.outer_proof.proof_type {
            ProofType::Recursive(outer_data, claimed_inner_hash) => {
                if claimed_inner_hash.as_slice() != inner_hash.as_bytes() {
                    return Ok(false);
                }

                let mut hasher = blake3::Hasher::new();
                hasher.update(outer_data);
                hasher.update(inner_hash.as_bytes());
                let expected = hasher.finalize();

                if outer_data.len() >= 32 {
                    let outer_hash = &outer_data[..32];
                    Ok(outer_hash == expected.as_bytes())
                } else {
                    Ok(false)
                }
            }
            _ => Err(ZkpError::RecursiveCompositionFailed(
                "outer proof must be recursive type".into(),
            )),
        }
    }

    pub fn compress_batch(proofs: &[ZkpProof]) -> ZkpResult<ZkpProof> {
        let batch = Self::aggregate_batch(proofs)?;
        let aggregate_proof_bytes = {
            let mut data = Vec::new();
            data.extend_from_slice(&batch.batch_root);
            data.extend_from_slice(&(batch.proof_count as u32).to_le_bytes());
            data
        };

        Ok(ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Batch(vec![aggregate_proof_bytes]),
            vec![batch.batch_root.to_vec()],
        )
        .with_circuit_id("batch-compressed")
        .with_security_level(128))
    }
}

impl Default for ProofAggregator {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::zkp::{ProofSystem, ProofType, ZkpProof};

    fn make_dummy_proof(id: u8) -> ZkpProof {
        ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Single(vec![id; 32]),
            vec![vec![id; 8]],
        )
        .with_circuit_id(format!("circuit-{}", id))
    }

    #[test]
    fn test_batch_aggregation() {
        let proofs: Vec<ZkpProof> = (0..5).map(|i| make_dummy_proof(i)).collect();
        let batch = ProofAggregator::aggregate_batch(&proofs).unwrap();
        assert_eq!(batch.proof_count, 5);
        assert!(ProofAggregator::verify_batch(&batch).unwrap());
    }

    #[test]
    fn test_empty_batch_error() {
        let result = ProofAggregator::aggregate_batch(&[]);
        assert!(result.is_err());
    }

    #[test]
    fn test_batch_verification_failure() {
        let proofs: Vec<ZkpProof> = (0..3).map(|i| make_dummy_proof(i)).collect();
        let mut batch = ProofAggregator::aggregate_batch(&proofs).unwrap();
        batch.batch_root = [0u8; 32];
        assert!(!ProofAggregator::verify_batch(&batch).unwrap());
    }

    #[test]
    fn test_recursive_composition() {
        let inner = make_dummy_proof(42);
        let recursive = ProofAggregator::compose_recursive(inner, ProofSystem::RiscZero).unwrap();
        assert_eq!(recursive.composition_depth, 1);
        assert!(ProofAggregator::verify_recursive(&recursive).unwrap());
    }

    #[test]
    fn test_recursive_tampered() {
        let inner = make_dummy_proof(0);
        let mut recursive = ProofAggregator::compose_recursive(inner, ProofSystem::RiscZero).unwrap();
        if let ProofType::Recursive(ref mut outer_data, _) = recursive.outer_proof.proof_type {
            if !outer_data.is_empty() {
                outer_data[0] ^= 0xFF;
            }
        }
        assert!(!ProofAggregator::verify_recursive(&recursive).unwrap());
    }

    #[test]
    fn test_batch_compression() {
        let proofs: Vec<ZkpProof> = (0..10).map(|i| make_dummy_proof(i)).collect();
        let compressed = ProofAggregator::compress_batch(&proofs).unwrap();
        assert_eq!(compressed.proof_system, ProofSystem::Noir);
        match &compressed.proof_type {
            ProofType::Batch(data) => assert!(!data.is_empty()),
            _ => panic!("expected batch proof type"),
        }
    }

    #[test]
    fn test_different_systems_rejected() {
        let proof1 = ZkpProof::new(ProofSystem::Noir, ProofType::Single(vec![0; 32]), vec![]);
        let proof2 = ZkpProof::new(ProofSystem::RiscZero, ProofType::Single(vec![1; 32]), vec![]);
        let result = ProofAggregator::aggregate_batch(&[proof1, proof2]);
        assert!(result.is_err());
    }
}
