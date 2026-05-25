struct Receipt {
    signal_hash: Field,
    station_id: Field,
    timestamp: Field,
    merkle_root: Field,
    signature: [Field; 4],
}

impl Receipt {
    fn to_bytes(self) -> [Field; 8] {
        let mut bytes: [Field; 8] = [0; 8];
        bytes[0] = self.signal_hash;
        bytes[1] = self.station_id;
        bytes[2] = self.timestamp;
        bytes[3] = self.merkle_root;
        bytes[4] = self.signature[0];
        bytes[5] = self.signature[1];
        bytes[6] = self.signature[2];
        bytes[7] = self.signature[3];
        bytes
    }

    fn from_bytes(bytes: [Field; 8]) -> Self {
        Receipt {
            signal_hash: bytes[0],
            station_id: bytes[1],
            timestamp: bytes[2],
            merkle_root: bytes[3],
            signature: [bytes[4], bytes[5], bytes[6], bytes[7]],
        }
    }

    fn assert_eq(self, other: Receipt) {
        assert(self.signal_hash == other.signal_hash);
        assert(self.station_id == other.station_id);
        assert(self.timestamp == other.timestamp);
        assert(self.merkle_root == other.merkle_root);
        assert(self.signature[0] == other.signature[0]);
        assert(self.signature[1] == other.signature[1]);
        assert(self.signature[2] == other.signature[2]);
        assert(self.signature[3] == other.signature[3]);
    }
}
