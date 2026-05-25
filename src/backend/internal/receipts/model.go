package receipts

import (
	"time"
)

type ReceiptStatus string

const (
	ReceiptStatusPending    ReceiptStatus = "pending"
	ReceiptStatusVerified   ReceiptStatus = "verified"
	ReceiptStatusInvalid    ReceiptStatus = "invalid"
	ReceiptStatusDisputed   ReceiptStatus = "disputed"
	ReceiptStatusAnchored   ReceiptStatus = "anchored"
)

type ProofType string

const (
	ProofTypeSignature ProofType = "signature"
	ProofTypeMerkle    ProofType = "merkle"
	ProofTypeHashchain ProofType = "hashchain"
	ProofTypeHybrid    ProofType = "hybrid"
)

type Receipt struct {
	ID             string       `json:"id"`
	StationID      string       `json:"station_id"`
	ScheduleID     string       `json:"schedule_id,omitempty"`
	TaskID         string       `json:"task_id,omitempty"`
	SignalID       string       `json:"signal_id,omitempty"`
	Status         ReceiptStatus `json:"status"`
	Proof          ProofData    `json:"proof"`
	PrevReceiptID  string       `json:"prev_receipt_id,omitempty"`
	ChainPosition  int64        `json:"chain_position"`
	MerkleRoot     string       `json:"merkle_root,omitempty"`
	Metadata       map[string]string `json:"metadata,omitempty"`
	CreatedAt      time.Time    `json:"created_at"`
	VerifiedAt     *time.Time   `json:"verified_at,omitempty"`
}

type ProofData struct {
	Type      ProofType `json:"type"`
	Algorithm string    `json:"algorithm"`
	Value     string    `json:"value"`
	PublicKey string    `json:"public_key,omitempty"`
	Nonce     string    `json:"nonce,omitempty"`
	Signature string    `json:"signature,omitempty"`
	Hash      string    `json:"hash,omitempty"`
	PrevHash  string    `json:"prev_hash,omitempty"`
}

type CreateReceiptInput struct {
	StationID  string            `json:"station_id" validate:"required"`
	ScheduleID string            `json:"schedule_id,omitempty"`
	TaskID     string            `json:"task_id,omitempty"`
	SignalID   string            `json:"signal_id,omitempty"`
	Proof      ProofData         `json:"proof" validate:"required"`
	Metadata   map[string]string `json:"metadata,omitempty"`
}

type VerifyReceiptInput struct {
	ReceiptID   string `json:"receipt_id" validate:"required"`
	StationID   string `json:"station_id" validate:"required"`
	ProofValue  string `json:"proof_value" validate:"required"`
	PublicKey   string `json:"public_key" validate:"required"`
}

type ReceiptFilter struct {
	StationID string        `json:"station_id,omitempty"`
	Status    *ReceiptStatus `json:"status,omitempty"`
	FromDate  *time.Time    `json:"from_date,omitempty"`
	ToDate    *time.Time    `json:"to_date,omitempty"`
	Limit     int           `json:"limit,omitempty"`
	Offset    int           `json:"offset,omitempty"`
}

type VerificationResult struct {
	IsValid      bool      `json:"is_valid"`
	ReceiptID    string    `json:"receipt_id"`
	VerifiedAt   time.Time `json:"verified_at"`
	ErrorMessage string    `json:"error_message,omitempty"`
	ChainStatus  string    `json:"chain_status,omitempty"`
}
