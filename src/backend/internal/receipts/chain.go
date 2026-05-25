package receipts

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/google/uuid"
)

type ChainService interface {
	Append(ctx context.Context, rcpt *Receipt) (*Receipt, error)
	VerifyChain(ctx context.Context, stationID string) (*ChainVerificationResult, error)
	GetChain(ctx context.Context, stationID string, limit int) ([]*Receipt, error)
	ComputeMerkleRoot(receipts []*Receipt) string
}

type chainService struct {
	repo Repository
}

func NewChainService(repo Repository) ChainService {
	return &chainService{repo: repo}
}

type ChainVerificationResult struct {
	IsValid          bool     `json:"is_valid"`
	ChainLength      int      `json:"chain_length"`
	VerifiedLinks    int      `json:"verified_links"`
	BrokenLinks      int      `json:"broken_links"`
	StationID        string   `json:"station_id"`
	LastReceiptID    string   `json:"last_receipt_id,omitempty"`
	MerkleRoot       string   `json:"merkle_root"`
	ComputedRoot     string   `json:"computed_root"`
	Error            string   `json:"error,omitempty"`
}

func (s *chainService) Append(ctx context.Context, rcpt *Receipt) (*Receipt, error) {
	lastReceipt, err := s.repo.GetLastByStation(ctx, rcpt.StationID)
	if err != nil {
		return nil, fmt.Errorf("getting last receipt: %w", err)
	}

	chainPosition := int64(1)
	if lastReceipt != nil {
		rcpt.PrevReceiptID = lastReceipt.ID
		chainPosition = lastReceipt.ChainPosition + 1
	}
	rcpt.ChainPosition = chainPosition

	if rcpt.ID == "" {
		rcpt.ID = uuid.New().String()
	}
	if rcpt.Status == "" {
		rcpt.Status = ReceiptStatusPending
	}
	if rcpt.CreatedAt.IsZero() {
		rcpt.CreatedAt = time.Now().UTC()
	}

	rcpt.Proof.PrevHash = s.computeReceiptHash(lastReceipt)

	if err := s.repo.Create(ctx, rcpt); err != nil {
		return nil, fmt.Errorf("appending receipt to chain: %w", err)
	}

	chain, err := s.repo.GetChain(ctx, rcpt.StationID, 100)
	if err == nil && len(chain) > 0 {
		rcpt.MerkleRoot = s.ComputeMerkleRoot(chain)
	}

	return rcpt, nil
}

func (s *chainService) VerifyChain(ctx context.Context, stationID string) (*ChainVerificationResult, error) {
	chain, err := s.repo.GetChain(ctx, stationID, 10000)
	if err != nil {
		return nil, fmt.Errorf("getting chain: %w", err)
	}

	result := &ChainVerificationResult{
		StationID:   stationID,
		ChainLength: len(chain),
		IsValid:     true,
	}

	if len(chain) == 0 {
		result.MerkleRoot = s.ComputeMerkleRoot(chain)
		result.ComputedRoot = result.MerkleRoot
		return result, nil
	}

	result.LastReceiptID = chain[len(chain)-1].ID

	for i, rcpt := range chain {
		if i == 0 {
			if rcpt.PrevReceiptID != "" {
				result.BrokenLinks++
				result.IsValid = false
			}
			continue
		}

		prevRec := chain[i-1]
		if rcpt.PrevReceiptID != prevRec.ID {
			result.BrokenLinks++
			result.IsValid = false
		} else {
			result.VerifiedLinks++
		}

		expectedPrevHash := s.computeReceiptHash(prevRec)
		if rcpt.Proof.PrevHash != expectedPrevHash {
			result.BrokenLinks++
			result.IsValid = false
		} else {
			result.VerifiedLinks++
		}
	}

	result.MerkleRoot = chain[len(chain)-1].MerkleRoot
	result.ComputedRoot = s.ComputeMerkleRoot(chain)

	if result.MerkleRoot != "" && result.MerkleRoot != result.ComputedRoot {
		result.IsValid = false
		result.BrokenLinks++
	}

	return result, nil
}

func (s *chainService) GetChain(ctx context.Context, stationID string, limit int) ([]*Receipt, error) {
	if limit <= 0 || limit > 10000 {
		limit = 100
	}
	return s.repo.GetChain(ctx, stationID, limit)
}

func (s *chainService) ComputeMerkleRoot(receipts []*Receipt) string {
	if len(receipts) == 0 {
		return ""
	}

	hashes := make([]string, len(receipts))
	for i, rcpt := range receipts {
		hashes[i] = s.hashReceipt(rcpt)
	}

	for len(hashes) > 1 {
		if len(hashes)%2 != 0 {
			hashes = append(hashes, hashes[len(hashes)-1])
		}

		var nextLevel []string
		for i := 0; i < len(hashes); i += 2 {
			combined := hashes[i] + hashes[i+1]
			h := sha256.Sum256([]byte(combined))
			nextLevel = append(nextLevel, hex.EncodeToString(h[:]))
		}
		hashes = nextLevel
	}

	return hashes[0]
}

func (s *chainService) computeReceiptHash(rcpt *Receipt) string {
	if rcpt == nil {
		return ""
	}
	h := sha256.Sum256([]byte(rcpt.ID + rcpt.StationID + string(rcpt.CreatedAt.Unix())))
	return hex.EncodeToString(h[:])
}

func (s *chainService) hashReceipt(rcpt *Receipt) string {
	data := fmt.Sprintf("%s:%s:%s:%d:%s",
		rcpt.ID, rcpt.StationID, rcpt.Status, rcpt.ChainPosition, rcpt.Proof.Hash)
	h := sha256.Sum256([]byte(data))
	return hex.EncodeToString(h[:])
}
