use crate::types;

struct ReceiptWitness {
    signal_hash: Field,
    station_id: Field,
    timestamp: Field,
    merkle_proof: [Field; 8],
    salt: Field,
}

impl ReceiptWitness {
    fn compute_witness(self) -> [Field; 12] {
        let mut witness: [Field; 12] = [0; 12];
        witness[0] = self.signal_hash;
        witness[1] = self.station_id;
        witness[2] = self.timestamp;
        witness[3] = self.merkle_proof[0];
        witness[4] = self.merkle_proof[1];
        witness[5] = self.merkle_proof[2];
        witness[6] = self.merkle_proof[3];
        witness[7] = self.merkle_proof[4];
        witness[8] = self.merkle_proof[5];
        witness[9] = self.merkle_proof[6];
        witness[10] = self.merkle_proof[7];
        witness[11] = self.salt;
        witness
    }

    fn generate_proof(self, merkle_root: Field) -> Field {
        let computed_root = compute_merkle_root(self.signal_hash, self.merkle_proof);

        let root_match = computed_root == merkle_root;

        let timestamp_valid = (self.timestamp as u64) > 0;

        let witness_hash = std::hash::pedersen(self.compute_witness());

        let proof: Field = if root_match & (timestamp_valid as Field) {
            witness_hash[0]
        } else {
            0
        };

        proof
    }
}

fn compute_merkle_root(leaf: Field, siblings: [Field; 8]) -> Field {
    let mut current = leaf;

    for i in 0..8 {
        let mut hash_input: [Field; 2] = [0; 2];
        hash_input[0] = current;
        hash_input[1] = siblings[i];
        let hash_result = std::hash::pedersen(hash_input);
        current = hash_result[0];
    }

    current
}

fn verify_merkle_proof(leaf: Field, root: Field, proof: [Field; 8]) -> bool {
    let computed = compute_merkle_root(leaf, proof);
    computed == root
}
