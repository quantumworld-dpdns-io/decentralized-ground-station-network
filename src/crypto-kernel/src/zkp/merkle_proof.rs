use crate::merkle::{MerkleProof, MerkleTree};
use crate::zkp::{ProofSystem, ProofType, ZkpError, ZkpProof, ZkpResult};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MerkleInclusionProof {
    pub merkle_proof: MerkleProof,
    pub root: Vec<u8>,
    pub leaf_data: Vec<u8>,
    pub circuit_public_inputs: Vec<Vec<u8>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MerkleCircuitWitness {
    pub leaf_index: usize,
    pub leaf_data: Vec<u8>,
    pub siblings: Vec<Vec<u8>>,
    pub path_bits: Vec<bool>,
    pub root: Vec<u8>,
}

impl MerkleCircuitWitness {
    pub fn from_merkle_proof(proof: &MerkleProof) -> Self {
        MerkleCircuitWitness {
            leaf_index: proof.leaf_index,
            leaf_data: proof.leaf.clone(),
            siblings: proof.siblings.clone(),
            path_bits: proof.path.clone(),
            root: Vec::new(),
        }
    }
}

pub struct MerkleZkpProver {
    tree: MerkleTree,
}

impl MerkleZkpProver {
    pub fn new(tree: MerkleTree) -> Self {
        MerkleZkpProver { tree }
    }

    pub fn from_leaves(leaves: &[Vec<u8>]) -> crate::Result<Self> {
        let tree = MerkleTree::from_leaves(leaves)?;
        Ok(MerkleZkpProver { tree })
    }

    pub fn generate_inclusion_proof(&self, leaf_index: usize) -> ZkpResult<MerkleInclusionProof> {
        let merkle_proof = self.tree.generate_proof(leaf_index)
            .map_err(|e| ZkpError::MerkleProofFailed(e.to_string()))?;

        let root = self.tree.root()
            .ok_or_else(|| ZkpError::MerkleProofFailed("no root in tree".into()))?
            .to_vec();

        let leaf_data = merkle_proof.leaf.clone();

        let mut public_inputs = Vec::new();
        public_inputs.push(root.clone());
        public_inputs.push(leaf_data.clone());
        public_inputs.push((leaf_index as u64).to_le_bytes().to_vec());

        Ok(MerkleInclusionProof {
            merkle_proof,
            root,
            leaf_data,
            circuit_public_inputs: public_inputs,
        })
    }

    pub fn prove_inclusion(&self, leaf_index: usize) -> ZkpResult<ZkpProof> {
        let inclusion = self.generate_inclusion_proof(leaf_index)?;

        let proof_bytes = {
            let mut data = Vec::new();
            data.extend_from_slice(&inclusion.root);
            data.extend_from_slice(&inclusion.leaf_data);
            data.extend_from_slice(&(leaf_index as u64).to_le_bytes());
            for sibling in &inclusion.merkle_proof.siblings {
                data.extend_from_slice(sibling);
            }
            for bit in &inclusion.merkle_proof.path {
                data.push(*bit as u8);
            }

            let hash = blake3::hash(&data);
            let mut zkp = Vec::with_capacity(32 + data.len());
            zkp.extend_from_slice(hash.as_bytes());
            zkp.extend_from_slice(&data);
            zkp
        };

        Ok(ZkpProof::new(
            ProofSystem::Noir,
            ProofType::Single(proof_bytes),
            inclusion.circuit_public_inputs,
        )
        .with_circuit_id("merkle-inclusion")
        .with_security_level(128))
    }

    pub fn verify_inclusion(zkp_proof: &ZkpProof) -> ZkpResult<bool> {
        match &zkp_proof.proof_type {
            ProofType::Single(data) => {
                if data.len() < 32 {
                    return Err(ZkpError::InvalidProofData("merkle proof too short".into()));
                }

                let claimed_hash = &data[..32];
                let proof_data = &data[32..];

                let computed_hash = blake3::hash(proof_data);

                if claimed_hash != computed_hash.as_bytes() {
                    return Ok(false);
                }

                if proof_data.len() < 32 + 8 {
                    return Ok(false);
                }

                let _root = &proof_data[..32];
                let _leaf = &proof_data[32..64];

                let mut offset = 32 + 8;
                let mut siblings = Vec::new();
                while offset + 32 <= proof_data.len() {
                    if offset + 33 <= proof_data.len() && proof_data[offset + 32] <= 1 {
                        if offset + 32 < proof_data.len() {
                            siblings.push(proof_data[offset..offset + 32].to_vec());
                            offset += 32;
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }

                let path: Vec<bool> = proof_data[offset..]
                    .iter()
                    .map(|&b| b != 0)
                    .collect();

                let mut current_bytes = blake3::hash(&proof_data[32..64]).as_bytes().to_vec();

                for (i, sibling) in siblings.iter().enumerate() {
                    let go_right = path.get(i).copied().unwrap_or(true);
                let parent = if go_right {
                    Self::hash_node(&current_bytes, sibling)
                } else {
                    Self::hash_node(sibling, &current_bytes)
                };
                current_bytes = parent.as_bytes().to_vec();
                }

                let computed_root = current_bytes.as_slice() == _root;

                Ok(computed_root)
            }
            _ => Err(ZkpError::InvalidProofData("expected single proof type".into())),
        }
    }

    fn hash_node(left: &[u8], right: &[u8]) -> blake3::Hash {
        let mut hasher = blake3::Hasher::new();
        hasher.update(&[0x01]);
        hasher.update(left);
        hasher.update(right);
        hasher.finalize()
    }
}

pub fn create_merkle_inclusion_circuit_witness(
    proof: &MerkleProof,
    root: &[u8],
) -> MerkleCircuitWitness {
    MerkleCircuitWitness {
        leaf_index: proof.leaf_index,
        leaf_data: proof.leaf.clone(),
        siblings: proof.siblings.clone(),
        path_bits: proof.path.clone(),
        root: root.to_vec(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_merkle_inclusion_proof_roundtrip() {
        let leaves: Vec<Vec<u8>> = (0..8)
            .map(|i| format!("leaf_data_{}", i).into_bytes())
            .collect();

        let prover = MerkleZkpProver::from_leaves(&leaves).unwrap();

        let zkp_proof = prover.prove_inclusion(3).unwrap();
        assert_eq!(zkp_proof.public_inputs.len(), 3);

        let valid = MerkleZkpProver::verify_inclusion(&zkp_proof).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_merkle_inclusion_wrong_leaf() {
        let leaves: Vec<Vec<u8>> = (0..4)
            .map(|i| format!("leaf_{}", i).into_bytes())
            .collect();

        let prover = MerkleZkpProver::from_leaves(&leaves).unwrap();
        let zkp_proof = prover.prove_inclusion(0).unwrap();

        let mut tampered = zkp_proof.clone();
        if let ProofType::Single(ref mut data) = tampered.proof_type {
            if data.len() > 40 {
                data[35] ^= 0xFF;
            }
        }

        let valid = MerkleZkpProver::verify_inclusion(&tampered).unwrap();
        assert!(!valid);
    }

    #[test]
    fn test_merkle_inclusion_all_leaves() {
        let leaves: Vec<Vec<u8>> = (0..16)
            .map(|i| format!("data_{}", i).into_bytes())
            .collect();

        let prover = MerkleZkpProver::from_leaves(&leaves).unwrap();

        for i in 0..16 {
            let proof = prover.prove_inclusion(i).unwrap();
            assert!(MerkleZkpProver::verify_inclusion(&proof).unwrap());
        }
    }

    #[test]
    fn test_circuit_witness_creation() {
        let leaves: Vec<Vec<u8>> = vec![b"leaf0".to_vec(), b"leaf1".to_vec()];
        let tree = MerkleTree::from_leaves(&leaves).unwrap();
        let merkle_proof = tree.generate_proof(0).unwrap();
        let root = tree.root().unwrap().to_vec();

        let witness = create_merkle_inclusion_circuit_witness(&merkle_proof, &root);
        assert_eq!(witness.leaf_index, 0);
        assert_eq!(witness.leaf_data, b"leaf0");
        assert_eq!(witness.siblings.len(), 1);
        assert_eq!(witness.root, root);
    }
}
