use serde::{Deserialize, Serialize};
use std::fmt::Debug;

pub trait Serializable: Sized {
    type Error: std::error::Error;

    fn to_binary(&self) -> Result<Vec<u8>, Self::Error>;
    fn from_binary(data: &[u8]) -> Result<Self, Self::Error>;

    fn to_json(&self) -> Result<String, Self::Error>
    where
        Self: Serialize,
    {
        serde_json::to_string(self)
            .map_err(|e| make_error(format!("JSON serialization failed: {}", e)))
    }

    fn from_json(json: &str) -> Result<Self, Self::Error>
    where
        Self: Deserialize<'static>,
    {
        serde_json::from_str(json)
            .map_err(|e| make_error(format!("JSON deserialization failed: {}", e)))
    }

    fn to_json_pretty(&self) -> Result<String, Self::Error>
    where
        Self: Serialize,
    {
        serde_json::to_string_pretty(self)
            .map_err(|e| make_error(format!("JSON pretty serialization failed: {}", e)))
    }
}

fn make_error(msg: String) -> Box<dyn std::error::Error> {
    Box::new(std::io::Error::new(std::io::ErrorKind::InvalidData, msg))
}

#[derive(Debug, Clone)]
pub struct SerializationError {
    pub message: String,
    pub kind: SerializationErrorKind,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SerializationErrorKind {
    Binary,
    Json,
    InvalidFormat,
    UnsupportedVersion,
    DataCorrupted,
}

impl SerializationError {
    pub fn new(message: impl Into<String>, kind: SerializationErrorKind) -> Self {
        SerializationError {
            message: message.into(),
            kind,
        }
    }
}

impl std::fmt::Display for SerializationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}: {}", self.kind, self.message)
    }
}

impl std::error::Error for SerializationError {}

impl From<SerializationError> for crate::CryptoError {
    fn from(e: SerializationError) -> Self {
        crate::CryptoError::SerializationFailed(e.message)
    }
}

pub trait CryptoSerializable: Serializable + Serialize + Deserialize<'static> {}

impl<T: Serializable + Serialize + Deserialize<'static>> CryptoSerializable for T {}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CryptoContainer {
    pub version: u8,
    pub algorithm: String,
    pub key_type: String,
    pub data: Vec<u8>,
    pub metadata: Option<CryptoMetadata>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CryptoMetadata {
    pub created_at: u64,
    pub key_id: Option<String>,
    pub signature: Option<Vec<u8>>,
    pub tags: Vec<String>,
}

impl CryptoContainer {
    pub fn new(algorithm: &str, key_type: &str, data: Vec<u8>) -> Self {
        CryptoContainer {
            version: 1,
            algorithm: algorithm.to_string(),
            key_type: key_type.to_string(),
            data,
            metadata: None,
        }
    }

    pub fn with_metadata(mut self, metadata: CryptoMetadata) -> Self {
        self.metadata = Some(metadata);
        self
    }
}

pub mod binary {
    use super::*;

    pub fn serialize<T: Serialize>(value: &T) -> Result<Vec<u8>, SerializationError> {
        bincode::serialize(value)
            .map_err(|e| SerializationError::new(format!("bincode serialize: {}", e), SerializationErrorKind::Binary))
    }

    pub fn deserialize<'a, T: Deserialize<'a>>(data: &'a [u8]) -> Result<T, SerializationError> {
        bincode::deserialize(data)
            .map_err(|e| SerializationError::new(format!("bincode deserialize: {}", e), SerializationErrorKind::Binary))
    }

    pub fn serialize_into<T: Serialize>(value: &T, writer: &mut impl std::io::Write) -> Result<(), SerializationError> {
        bincode::serialize_into(writer, value)
            .map_err(|e| SerializationError::new(format!("bincode serialize_into: {}", e), SerializationErrorKind::Binary))
    }

    pub fn deserialize_from<T: Deserialize<'static>, R: std::io::Read>(reader: R) -> Result<T, SerializationError> {
        bincode::deserialize_from(reader)
            .map_err(|e| SerializationError::new(format!("bincode deserialize_from: {}", e), SerializationErrorKind::Binary))
    }
}

pub mod json {
    use super::*;

    pub fn serialize<T: Serialize>(value: &T) -> Result<String, SerializationError> {
        serde_json::to_string(value)
            .map_err(|e| SerializationError::new(format!("JSON serialize: {}", e), SerializationErrorKind::Json))
    }

    pub fn deserialize<'a, T: Deserialize<'a>>(json: &'a str) -> Result<T, SerializationError> {
        serde_json::from_str(json)
            .map_err(|e| SerializationError::new(format!("JSON deserialize: {}", e), SerializationErrorKind::Json))
    }

    pub fn to_writer<T: Serialize>(value: &T, writer: &mut impl std::io::Write) -> Result<(), SerializationError> {
        serde_json::to_writer(writer, value)
            .map_err(|e| SerializationError::new(format!("JSON to_writer: {}", e), SerializationErrorKind::Json))
    }

    pub fn from_reader<T: Deserialize<'static>, R: std::io::Read>(reader: R) -> Result<T, SerializationError> {
        serde_json::from_reader(reader)
            .map_err(|e| SerializationError::new(format!("JSON from_reader: {}", e), SerializationErrorKind::Json))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
    struct TestKey {
        algorithm: String,
        public_key: Vec<u8>,
        secret_key: Vec<u8>,
    }

    #[test]
    fn test_binary_roundtrip() {
        let key = TestKey {
            algorithm: "ML-KEM-768".to_string(),
            public_key: vec![1, 2, 3, 4],
            secret_key: vec![5, 6, 7, 8],
        };

        let bytes = binary::serialize(&key).unwrap();
        let deserialized: TestKey = binary::deserialize(&bytes).unwrap();
        assert_eq!(key, deserialized);
    }

    #[test]
    fn test_json_roundtrip() {
        let key = TestKey {
            algorithm: "ML-DSA-65".to_string(),
            public_key: vec![10, 20, 30],
            secret_key: vec![40, 50, 60],
        };

        let json = json::serialize(&key).unwrap();
        let deserialized: TestKey = json::deserialize(&json).unwrap();
        assert_eq!(key, deserialized);
    }

    #[test]
    fn test_crypto_container() {
        let container = CryptoContainer::new("ML-KEM-768", "public", vec![1, 2, 3])
            .with_metadata(CryptoMetadata {
                created_at: 1718000000,
                key_id: Some("key-001".to_string()),
                signature: None,
                tags: vec!["test".to_string()],
            });

        let json = json::serialize(&container).unwrap();
        let deserialized: CryptoContainer = json::deserialize(&json).unwrap();
        assert_eq!(container.algorithm, deserialized.algorithm);
        assert_eq!(container.data, deserialized.data);
        assert_eq!(container.metadata.as_ref().unwrap().key_id, deserialized.metadata.as_ref().unwrap().key_id);
    }

    #[test]
    fn test_binary_container_roundtrip() {
        let container = CryptoContainer::new("ML-DSA-87", "secret", vec![0; 64]);
        let bytes = binary::serialize(&container).unwrap();
        let deserialized: CryptoContainer = binary::deserialize(&bytes).unwrap();
        assert_eq!(container.version, deserialized.version);
        assert_eq!(container.data.len(), deserialized.data.len());
    }

    #[test]
    fn test_binary_large_data() {
        let data: Vec<u8> = (0..1024).map(|i| (i % 256) as u8).collect();
        let container = CryptoContainer::new("ML-KEM-1024", "public", data);
        let bytes = binary::serialize(&container).unwrap();
        let deserialized: CryptoContainer = binary::deserialize(&bytes).unwrap();
        assert_eq!(container.data.len(), deserialized.data.len());
        assert_eq!(container.data, deserialized.data);
    }
}
