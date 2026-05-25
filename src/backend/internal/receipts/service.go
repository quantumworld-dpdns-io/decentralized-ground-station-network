package receipts

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/dgsn/pkg/crypto"
)

var (
	ErrReceiptNotFound = errors.New("receipt not found")
	ErrInvalidProof    = errors.New("invalid proof")
	ErrDuplicateEntry  = errors.New("duplicate receipt entry")
)

type Service interface {
	Create(ctx context.Context, input CreateReceiptInput) (*Receipt, error)
	Get(ctx context.Context, id string) (*Receipt, error)
	List(ctx context.Context, filter ReceiptFilter) ([]*Receipt, error)
	Verify(ctx context.Context, input VerifyReceiptInput) (*VerificationResult, error)
	Delete(ctx context.Context, id string) error
}

type service struct {
	repo    Repository
	chain   ChainService
	signer  crypto.Signer
}

func NewService(repo Repository, chain ChainService, signer crypto.Signer) Service {
	return &service{
		repo:   repo,
		chain:  chain,
		signer: signer,
	}
}

func (s *service) Create(ctx context.Context, input CreateReceiptInput) (*Receipt, error) {
	proofHash := sha256.Sum256([]byte(input.Proof.Value + input.Proof.Nonce))
	input.Proof.Hash = hex.EncodeToString(proofHash[:])

	existing, err := s.repo.GetByStationAndSchedule(ctx, input.StationID, input.ScheduleID)
	if err != nil {
		return nil, fmt.Errorf("checking existing receipt: %w", err)
	}
	if existing != nil {
		return nil, fmt.Errorf("%w: station %s schedule %s", ErrDuplicateEntry, input.StationID, input.ScheduleID)
	}

	sig, err := s.signer.Sign([]byte(input.Proof.Hash))
	if err != nil {
		return nil, fmt.Errorf("signing proof: %w", err)
	}
	input.Proof.Signature = string(sig)

	rcpt := &Receipt{
		ID:         uuid.New().String(),
		StationID:  input.StationID,
		ScheduleID: input.ScheduleID,
		TaskID:     input.TaskID,
		SignalID:   input.SignalID,
		Status:     ReceiptStatusPending,
		Proof:      input.Proof,
		Metadata:   input.Metadata,
		CreatedAt:  time.Now().UTC(),
	}

	appended, err := s.chain.Append(ctx, rcpt)
	if err != nil {
		return nil, fmt.Errorf("appending to receipt chain: %w", err)
	}

	return appended, nil
}

func (s *service) Get(ctx context.Context, id string) (*Receipt, error) {
	rcpt, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting receipt: %w", err)
	}
	return rcpt, nil
}

func (s *service) List(ctx context.Context, filter ReceiptFilter) ([]*Receipt, error) {
	if filter.Limit <= 0 || filter.Limit > 1000 {
		filter.Limit = 100
	}
	receipts, err := s.repo.List(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("listing receipts: %w", err)
	}
	return receipts, nil
}

func (s *service) Verify(ctx context.Context, input VerifyReceiptInput) (*VerificationResult, error) {
	rcpt, err := s.repo.GetByID(ctx, input.ReceiptID)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrReceiptNotFound, input.ReceiptID)
	}

	result := &VerificationResult{
		ReceiptID:  input.ReceiptID,
		VerifiedAt: time.Now().UTC(),
	}

	ok, err := s.signer.Verify([]byte(rcpt.Proof.Hash), []byte(rcpt.Proof.Signature), []byte(input.PublicKey))
	if err != nil {
		result.IsValid = false
		result.ErrorMessage = fmt.Sprintf("verification error: %v", err)
		return result, nil
	}
	if !ok {
		result.IsValid = false
		result.ErrorMessage = "signature verification failed"
		return result, nil
	}

	expectedHash := sha256.Sum256([]byte(input.ProofValue + rcpt.Proof.Nonce))
	if hex.EncodeToString(expectedHash[:]) != rcpt.Proof.Hash {
		result.IsValid = false
		result.ErrorMessage = "proof hash mismatch"
		return result, nil
	}

	chainResult, err := s.chain.VerifyChain(ctx, rcpt.StationID)
	if err != nil {
		result.IsValid = false
		result.ErrorMessage = fmt.Sprintf("chain verification error: %v", err)
		return result, nil
	}

	result.IsValid = chainResult.IsValid
	result.ChainStatus = fmt.Sprintf("chain_length=%d verified_links=%d",
		chainResult.ChainLength, chainResult.VerifiedLinks)

	if result.IsValid {
		rcpt.Status = ReceiptStatusVerified
		rcpt.VerifiedAt = &result.VerifiedAt
		if err := s.repo.Update(ctx, rcpt); err != nil {
			return result, fmt.Errorf("updating receipt status: %w", err)
		}
	}

	return result, nil
}

func (s *service) Delete(ctx context.Context, id string) error {
	if err := s.repo.Delete(ctx, id); err != nil {
		return fmt.Errorf("deleting receipt: %w", err)
	}
	return nil
}
