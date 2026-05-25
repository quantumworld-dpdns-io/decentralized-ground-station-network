use blake3::Hash;
use serde::{Deserialize, Serialize};
use std::fmt;

const MAX_HEIGHT: usize = 64;
const LEAF_HASH_PREFIX: u8 = 0x00;
const NODE_HASH_PREFIX: u8 = 0x01;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MerkleTree {
    nodes: Vec<Vec<u8>>,
    leaf_count: usize,
    height: usize,
    root: Option<Vec<u8>>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MerkleProof {
    pub leaf: Vec<u8>,
    pub leaf_index: usize,
    pub siblings: Vec<Vec<u8>>,
    pub path: Vec<bool>,
}

impl MerkleTree {
    pub fn new() -> Self {
        MerkleTree {
            nodes: Vec::new(),
            leaf_count: 0,
            height: 0,
            root: None,
        }
    }

    pub fn from_leaves(leaves: &[Vec<u8>]) -> crate::Result<Self> {
        if leaves.is_empty() {
            return Err(crate::CryptoError::MerkleError("cannot build tree from empty leaves".into()));
        }
        if leaves.len() > (1usize << (MAX_HEIGHT - 1).min(63)) {
            return Err(crate::CryptoError::MerkleError(
                format!("too many leaves: max is {}", 1usize << (MAX_HEIGHT - 1).min(63)),
            ));
        }

        let leaf_count = leaves.len();
        let height = (leaf_count as f64).log2().ceil() as usize + 1;

        let mut nodes = Vec::with_capacity(2 * leaf_count);

        for leaf in leaves {
            let leaf_hash = Self::hash_leaf(leaf);
            nodes.push(leaf_hash.as_bytes().to_vec());
        }

        let mut current_level = leaf_count;
        let mut level_size = leaf_count;

        while level_size > 1 {
            let next_size = (level_size + 1) / 2;
            for i in 0..next_size {
                let left = nodes[current_level - level_size + 2 * i].clone();
                let right = if 2 * i + 1 < level_size {
                    nodes[current_level - level_size + 2 * i + 1].clone()
                } else {
                    left.clone()
                };
                let parent = Self::hash_node(&left, &right);
                nodes.push(parent.as_bytes().to_vec());
            }
            current_level += next_size;
            level_size = next_size;
        }

        let root = nodes.last().cloned();

        Ok(MerkleTree {
            nodes,
            leaf_count,
            height,
            root,
        })
    }

    pub fn root(&self) -> Option<&[u8]> {
        self.root.as_deref()
    }

    pub fn leaf_count(&self) -> usize {
        self.leaf_count
    }

    pub fn height(&self) -> usize {
        self.height
    }

    pub fn generate_proof(&self, leaf_index: usize) -> crate::Result<MerkleProof> {
        if leaf_index >= self.leaf_count {
            return Err(crate::CryptoError::MerkleError(
                format!("leaf index {} out of bounds (max {})", leaf_index, self.leaf_count - 1),
            ));
        }

        let leaf = self.nodes[leaf_index].clone();
        let mut siblings = Vec::new();
        let mut path = Vec::new();

        let mut idx = leaf_index;
        let mut level_start = 0;
        let mut level_size = self.leaf_count;

        while level_size > 1 {
            let sibling_idx = if idx % 2 == 0 {
                path.push(true);
                if idx + 1 < level_size {
                    level_start + idx + 1
                } else {
                    level_start + idx
                }
            } else {
                path.push(false);
                level_start + idx - 1
            };

            let sibling = self.nodes.get(sibling_idx)
                .ok_or_else(|| crate::CryptoError::MerkleError("sibling not found".into()))?
                .clone();
            siblings.push(sibling);

            idx /= 2;
            level_start += level_size;
            level_size = (level_size + 1) / 2;
        }

        Ok(MerkleProof {
            leaf,
            leaf_index,
            siblings,
            path,
        })
    }

    pub fn verify_proof(proof: &MerkleProof, root: &[u8]) -> bool {
        let mut current_bytes = Self::hash_leaf(&proof.leaf).as_bytes().to_vec();

        for (i, sibling) in proof.siblings.iter().enumerate() {
            let go_right = proof.path[i];
            let parent = if go_right {
                Self::hash_node(&current_bytes, sibling)
            } else {
                Self::hash_node(sibling, &current_bytes)
            };
            current_bytes = parent.as_bytes().to_vec();
        }

        current_bytes.as_slice() == root
    }

    pub fn append(&mut self, leaf: Vec<u8>) -> crate::Result<()> {
        let new_leaves: Vec<Vec<u8>> = self.iter_leaves()
            .chain(std::iter::once(&leaf))
            .cloned()
            .collect();

        *self = Self::from_leaves(&new_leaves)?;
        Ok(())
    }

    pub fn iter_leaves(&self) -> impl Iterator<Item = &Vec<u8>> {
        self.nodes[..self.leaf_count].iter()
    }

    fn hash_leaf(data: &[u8]) -> Hash {
        let mut hasher = blake3::Hasher::new();
        hasher.update(&[LEAF_HASH_PREFIX]);
        hasher.update(data);
        hasher.finalize()
    }

    fn hash_node(left: &[u8], right: &[u8]) -> Hash {
        let mut hasher = blake3::Hasher::new();
        hasher.update(&[NODE_HASH_PREFIX]);
        hasher.update(left);
        hasher.update(right);
        hasher.finalize()
    }
}

impl Default for MerkleTree {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Display for MerkleTree {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "MerkleTree {{ leaf_count: {}, height: {}, root: {} }}",
            self.leaf_count,
            self.height,
            self.root.as_ref().map(|r| hex::encode(r)).unwrap_or_default()
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_tree() {
        let tree = MerkleTree::new();
        assert_eq!(tree.leaf_count(), 0);
        assert!(tree.root().is_none());
    }

    #[test]
    fn test_single_leaf() {
        let leaves = vec![b"leaf1".to_vec()];
        let tree = MerkleTree::from_leaves(&leaves).unwrap();
        assert_eq!(tree.leaf_count(), 1);
        assert!(tree.root().is_some());
    }

    #[test]
    fn test_multiple_leaves() {
        let leaves: Vec<Vec<u8>> = (0..8).map(|i| format!("leaf_{}", i).into_bytes()).collect();
        let tree = MerkleTree::from_leaves(&leaves).unwrap();
        assert_eq!(tree.leaf_count(), 8);
        assert!(tree.root().is_some());
    }

    #[test]
    fn test_proof_verification() {
        let leaves: Vec<Vec<u8>> = (0..4).map(|i| format!("data_{}", i).into_bytes()).collect();
        let tree = MerkleTree::from_leaves(&leaves).unwrap();
        let root = tree.root().unwrap().to_vec();

        for i in 0..4 {
            let proof = tree.generate_proof(i).unwrap();
            assert!(MerkleTree::verify_proof(&proof, &root));
        }
    }

    #[test]
    fn test_invalid_proof() {
        let leaves: Vec<Vec<u8>> = (0..4).map(|i| format!("data_{}", i).into_bytes()).collect();
        let tree = MerkleTree::from_leaves(&leaves).unwrap();
        let root = tree.root().unwrap().to_vec();

        let proof = tree.generate_proof(0).unwrap();
        let mut tampered_proof = proof.clone();
        tampered_proof.leaf = b"tampered_data".to_vec();
        assert!(!MerkleTree::verify_proof(&tampered_proof, &root));
    }

    #[test]
    fn test_append() {
        let leaves = vec![b"leaf1".to_vec()];
        let mut tree = MerkleTree::from_leaves(&leaves).unwrap();
        assert_eq!(tree.leaf_count(), 1);

        tree.append(b"leaf2".to_vec()).unwrap();
        assert_eq!(tree.leaf_count(), 2);
    }

    #[test]
    fn test_empty_leaves_error() {
        let result = MerkleTree::from_leaves(&[]);
        assert!(result.is_err());
    }

    #[test]
    fn test_verify_proof_wrong_root() {
        let leaves1: Vec<Vec<u8>> = (0..4).map(|i| format!("data_{}", i).into_bytes()).collect();
        let leaves2: Vec<Vec<u8>> = (0..4).map(|i| format!("other_{}", i).into_bytes()).collect();
        let tree1 = MerkleTree::from_leaves(&leaves1).unwrap();
        let tree2 = MerkleTree::from_leaves(&leaves2).unwrap();

        let proof = tree1.generate_proof(0).unwrap();
        let root2 = tree2.root().unwrap().to_vec();
        assert!(!MerkleTree::verify_proof(&proof, &root2));
    }

    #[test]
    fn test_large_tree() {
        let leaves: Vec<Vec<u8>> = (0..16).map(|i| format!("data_{}", i).into_bytes()).collect();
        let tree = MerkleTree::from_leaves(&leaves).unwrap();
        assert_eq!(tree.leaf_count(), 16);

        let root = tree.root().unwrap().to_vec();
        for i in 0..16 {
            let proof = tree.generate_proof(i).unwrap();
            assert!(MerkleTree::verify_proof(&proof, &root));
        }
    }
}
