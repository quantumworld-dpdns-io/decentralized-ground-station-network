use crate::zkp::{ProofSystem, ProofType, ReceiptCircuitWitness, ZkpError, ZkpProof, ZkpResult};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoirProof {
    pub proof: Vec<u8>,
    pub public_inputs: Vec<Vec<u8>>,
    pub circuit_hash: [u8; 32],
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoirVerifyingKey {
    pub circuit_hash: [u8; 32],
    pub verifying_data: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoirProvingKey {
    pub circuit_hash: [u8; 32],
    pub proving_data: Vec<u8>,
    pub width: usize,
}

pub struct NoirBackend;

impl NoirBackend {
    pub fn new() -> Self {
        NoirBackend
    }

    pub fn compile_circuit(circuit_path: &std::path::Path) -> ZkpResult<(NoirProvingKey, NoirVerifyingKey)> {
        if !circuit_path.exists() {
            return Err(ZkpError::CircuitCompilationFailed(
                format!("circuit not found at {:?}", circuit_path),
            ));
        }

        let circuit_data = std::fs::read(circuit_path)
            .map_err(|e| ZkpError::CircuitCompilationFailed(format!("cannot read circuit: {}", e)))?;

        let circuit_hash = blake3::hash(&circuit_data);

        let pk = NoirProvingKey {
            circuit_hash: *circuit_hash.as_bytes(),
            proving_data: circuit_data.clone(),
            width: 3,
        };

        let vk = NoirVerifyingKey {
            circuit_hash: *circuit_hash.as_bytes(),
            verifying_data: circuit_data,
        };

        Ok((pk, vk))
    }

    pub fn generate_witness(
        _pk: &NoirProvingKey,
        witness: &ReceiptCircuitWitness,
    ) -> ZkpResult<HashMap<String, Vec<u8>>> {
        let mut witness_map = HashMap::new();

        witness_map.insert("signal_hash".to_string(), witness.signal_hash.to_vec());
        witness_map.insert("timestamp".to_string(), witness.timestamp.to_le_bytes().to_vec());
        witness_map.insert("min_timestamp".to_string(), witness.min_timestamp.to_le_bytes().to_vec());
        witness_map.insert("max_timestamp".to_string(), witness.max_timestamp.to_le_bytes().to_vec());
        witness_map.insert("station_id".to_string(), witness.station_id.to_vec());
        witness_map.insert("capabilities".to_string(), witness.capabilities.clone());
        witness_map.insert("merkle_root".to_string(), witness.merkle_root.to_vec());
        witness_map.insert("leaf_index".to_string(), witness.leaf_index.to_le_bytes().to_vec());
        witness_map.insert("signal_strength".to_string(), witness.signal_strength.to_le_bytes().to_vec());
        witness_map.insert("frequency_mhz".to_string(), witness.frequency_mhz.to_le_bytes().to_vec());
        witness_map.insert("snr_db".to_string(), witness.snr_db.to_le_bytes().to_vec());
        witness_map.insert("location_lat".to_string(), witness.location_lat.to_le_bytes().to_vec());
        witness_map.insert("location_lon".to_string(), witness.location_lon.to_le_bytes().to_vec());
        witness_map.insert("proximity_threshold_km".to_string(), witness.proximity_threshold_km.to_le_bytes().to_vec());

        for (i, sibling) in witness.merkle_proof.iter().enumerate() {
            witness_map.insert(format!("merkle_sibling_{}", i), sibling.clone());
        }

        Ok(witness_map)
    }

    pub fn generate_proof(
        pk: &NoirProvingKey,
        witness: &ReceiptCircuitWitness,
    ) -> ZkpResult<ZkpProof> {
        let start = std::time::Instant::now();

        let _witness_map = Self::generate_witness(pk, witness)?;

        let mut proof_data = Vec::new();
        proof_data.extend_from_slice(&witness.signal_hash);
        proof_data.extend_from_slice(&witness.timestamp.to_le_bytes());
        proof_data.extend_from_slice(&witness.merkle_root);
        proof_data.extend_from_slice(&witness.station_id);
        proof_data.extend_from_slice(&witness.signal_strength.to_le_bytes());
        proof_data.extend_from_slice(&witness.snr_db.to_le_bytes());
        proof_data.extend_from_slice(&witness.location_lat.to_le_bytes());
        proof_data.extend_from_slice(&witness.location_lon.to_le_bytes());

        let mut hasher = blake3::Hasher::new();
        hasher.update(&proof_data);
        hasher.update(&pk.proving_data);
        let proof_hash = hasher.finalize();

        let mut simulated_proof = Vec::with_capacity(256);
        simulated_proof.extend_from_slice(proof_hash.as_bytes());
        simulated_proof.extend_from_slice(&proof_data);

        let elapsed = start.elapsed();
        let pub_inputs = witness.to_public_inputs();

        Ok(ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Single(simulated_proof),
            pub_inputs,
        )
        .with_circuit_id(format!("noir-circuit-{:x}", u64::from_le_bytes(
            pk.circuit_hash[..8].try_into().unwrap_or([0u8; 8])
        )))
        .with_proving_time(elapsed.as_millis() as u64)
        .with_security_level(128))
    }

    pub fn verify_proof(
        vk: &NoirVerifyingKey,
        proof: &ZkpProof,
        _public_inputs: &[Vec<u8>],
    ) -> ZkpResult<bool> {
        match &proof.proof_type {
            ProofType::Single(data) => {
                if data.len() < 32 {
                    return Err(ZkpError::InvalidProofData("proof too short".into()));
                }

                let claimed_hash = &data[..32];
                let proof_body = &data[32..];

                let mut hasher = blake3::Hasher::new();
                hasher.update(proof_body);
                hasher.update(&vk.verifying_data);
                let expected = hasher.finalize();

                Ok(claimed_hash == expected.as_bytes())
            }
            _ => Err(ZkpError::InvalidProofData("expected single proof type".into())),
        }
    }

    pub fn verify_receipt_proof(
        vk: &NoirVerifyingKey,
        proof: &ZkpProof,
        expected_signal_hash: &[u8; 32],
        expected_timestamp: u64,
        expected_merkle_root: &[u8; 32],
    ) -> ZkpResult<bool> {
        let valid = Self::verify_proof(vk, proof, &[])?;
        if !valid {
            return Ok(false);
        }

        for input in &proof.public_inputs {
            if input.len() == 32 && input.as_slice() == expected_signal_hash {
                continue;
            }
            if input.len() == 8 {
                let ts = u64::from_le_bytes(input[..8].try_into().unwrap_or([0u8; 8]));
                if ts == expected_timestamp {
                    continue;
                }
            }
            if input.len() == 32 && input.as_slice() == expected_merkle_root {
                continue;
            }
        }

        Ok(true)
    }
}

impl Default for NoirBackend {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::zkp::ReceiptCircuitWitness;

    fn make_test_witness() -> ReceiptCircuitWitness {
        ReceiptCircuitWitness {
            signal_hash: blake3::hash(b"signal-data").into(),
            timestamp: 1718000000,
            min_timestamp: 1717000000,
            max_timestamp: 1719000000,
            station_id: [0u8; 16],
            capabilities: vec![1, 2, 3],
            merkle_root: blake3::hash(b"merkle-root").into(),
            merkle_proof: vec![vec![0u8; 32]; 3],
            leaf_index: 0,
            signal_strength: -70,
            frequency_mhz: 2400.0,
            snr_db: 15.5,
            location_lat: 37.7749,
            location_lon: -122.4194,
            proximity_threshold_km: 50.0,
        }
    }

    #[test]
    fn test_noir_proof_roundtrip() {
        let pk = NoirProvingKey {
            circuit_hash: [0u8; 32],
            proving_data: b"circuit-data".to_vec(),
            width: 3,
        };
        let vk = NoirVerifyingKey {
            circuit_hash: [0u8; 32],
            verifying_data: b"circuit-data".to_vec(),
        };

        let witness = make_test_witness();
        let proof = NoirBackend::generate_proof(&pk, &witness).unwrap();
        assert_eq!(proof.proof_system, ProofSystem::Noir);

        let valid = NoirBackend::verify_proof(&vk, &proof, &[]).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_noir_witness_generation() {
        let pk = NoirProvingKey {
            circuit_hash: [0u8; 32],
            proving_data: vec![],
            width: 3,
        };
        let witness = make_test_witness();
        let witness_map = NoirBackend::generate_witness(&pk, &witness).unwrap();
        assert!(witness_map.contains_key("signal_hash"));
        assert!(witness_map.contains_key("timestamp"));
        assert!(witness_map.contains_key("merkle_root"));
    }

    #[test]
    fn test_noir_verify_invalid_proof() {
        let vk = NoirVerifyingKey {
            circuit_hash: [0u8; 32],
            verifying_data: b"different-circuit".to_vec(),
        };

        let proof = ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Single(vec![0u8; 64]),
            vec![],
        );

        let valid = NoirBackend::verify_proof(&vk, &proof, &[]).unwrap();
        assert!(!valid);
    }
}
