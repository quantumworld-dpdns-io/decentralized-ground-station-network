package crypto

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"errors"
	"fmt"
	"hash"
	"io"
	"sync"
)

var (
	ErrSignerNotInitialized = errors.New("signer not initialized")
	ErrInvalidKeySize       = errors.New("invalid key size")
	ErrVerificationFailed   = errors.New("signature verification failed")
)

type Signer interface {
	Sign(ctx context.Context, data []byte) ([]byte, error)
	Verify(ctx context.Context, data, signature []byte) (bool, error)
	PublicKey() []byte
	Algorithm() string
}

type Verifier interface {
	Verify(ctx context.Context, data, signature []byte) (bool, error)
	Algorithm() string
}

type HashSigner struct {
	privateKey ed25519.PrivateKey
	publicKey  ed25519.PublicKey
	hashFunc   func() hash.Hash
	algorithm  string
	mu         sync.RWMutex
}

type HashSignerConfig struct {
	PrivateKey []byte
	PublicKey  []byte
	HashFunc   func() hash.Hash
	Algorithm  string
}

func NewHashSigner(cfg *HashSignerConfig) (*HashSigner, error) {
	if cfg == nil {
		return nil, errors.New("config is nil")
	}

	s := &HashSigner{
		hashFunc:  cfg.HashFunc,
		algorithm: cfg.Algorithm,
	}

	if s.hashFunc == nil {
		s.hashFunc = sha256.New
	}

	if s.algorithm == "" {
		s.algorithm = "ED25519+SHA256"
	}

	if len(cfg.PrivateKey) > 0 {
		if len(cfg.PrivateKey) != ed25519.PrivateKeySize {
			return nil, fmt.Errorf("%w: expected %d bytes, got %d", ErrInvalidKeySize, ed25519.PrivateKeySize, len(cfg.PrivateKey))
		}
		s.privateKey = make(ed25519.PrivateKey, ed25519.PrivateKeySize)
		copy(s.privateKey, cfg.PrivateKey)
	}

	if len(cfg.PublicKey) > 0 {
		if len(cfg.PublicKey) != ed25519.PublicKeySize {
			return nil, fmt.Errorf("%w: expected %d bytes, got %d", ErrInvalidKeySize, ed25519.PublicKeySize, len(cfg.PublicKey))
		}
		s.publicKey = make(ed25519.PublicKey, ed25519.PublicKeySize)
		copy(s.publicKey, cfg.PublicKey)
	} else if s.privateKey != nil {
		s.publicKey = s.privateKey.Public().(ed25519.PublicKey)
	}

	return s, nil
}

func GenerateKeyPair() (ed25519.PublicKey, ed25519.PrivateKey, error) {
	return ed25519.GenerateKey(nil)
}

func (s *HashSigner) Sign(ctx context.Context, data []byte) ([]byte, error) {
	if s.privateKey == nil {
		return nil, ErrSignerNotInitialized
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	default:
	}

	h := s.hashFunc()
	h.Write(data)
	digest := h.Sum(nil)

	signature := ed25519.Sign(s.privateKey, digest)

	return signature, nil
}

func (s *HashSigner) SignStream(ctx context.Context, r io.Reader) ([]byte, error) {
	if s.privateKey == nil {
		return nil, ErrSignerNotInitialized
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	h := s.hashFunc()
	buf := make([]byte, 32*1024)

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}

		n, err := r.Read(buf)
		if err != nil && err != io.EOF {
			return nil, fmt.Errorf("reading stream: %w", err)
		}
		if n == 0 {
			break
		}
		h.Write(buf[:n])

		if err == io.EOF {
			break
		}
	}

	digest := h.Sum(nil)
	signature := ed25519.Sign(s.privateKey, digest)

	return signature, nil
}

func (s *HashSigner) Verify(ctx context.Context, data, signature []byte) (bool, error) {
	if s.publicKey == nil {
		return false, errors.New("verifier not initialized: no public key")
	}

	select {
	case <-ctx.Done():
		return false, ctx.Err()
	default:
	}

	if len(signature) != ed25519.SignatureSize {
		return false, fmt.Errorf("invalid signature size: expected %d, got %d", ed25519.SignatureSize, len(signature))
	}

	h := s.hashFunc()
	h.Write(data)
	digest := h.Sum(nil)

	valid := ed25519.Verify(s.publicKey, digest, signature)
	return valid, nil
}

func (s *HashSigner) VerifyStream(ctx context.Context, r io.Reader, signature []byte) (bool, error) {
	if s.publicKey == nil {
		return false, errors.New("verifier not initialized: no public key")
	}

	if len(signature) != ed25519.SignatureSize {
		return false, fmt.Errorf("invalid signature size: expected %d, got %d", ed25519.SignatureSize, len(signature))
	}

	h := s.hashFunc()
	buf := make([]byte, 32*1024)

	for {
		select {
		case <-ctx.Done():
			return false, ctx.Err()
		default:
		}

		n, err := r.Read(buf)
		if err != nil && err != io.EOF {
			return false, fmt.Errorf("reading stream: %w", err)
		}
		if n == 0 {
			break
		}
		h.Write(buf[:n])

		if err == io.EOF {
			break
		}
	}

	digest := h.Sum(nil)
	valid := ed25519.Verify(s.publicKey, digest, signature)
	return valid, nil
}

func (s *HashSigner) PublicKey() []byte {
	if s.publicKey == nil {
		return nil
	}
	pk := make([]byte, len(s.publicKey))
	copy(pk, s.publicKey)
	return pk
}

func (s *HashSigner) PublicKeyHex() string {
	return hex.EncodeToString(s.PublicKey())
}

func (s *HashSigner) Algorithm() string {
	return s.algorithm
}

type MultiSigner struct {
	signers map[string]Signer
	mu      sync.RWMutex
}

func NewMultiSigner() *MultiSigner {
	return &MultiSigner{
		signers: make(map[string]Signer),
	}
}

func (m *MultiSigner) AddSigner(id string, signer Signer) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.signers[id] = signer
}

func (m *MultiSigner) RemoveSigner(id string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.signers, id)
}

func (m *MultiSigner) SignAll(ctx context.Context, data []byte) (map[string][]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	signatures := make(map[string][]byte)
	errors := make(map[string]error)

	for id, signer := range m.signers {
		sig, err := signer.Sign(ctx, data)
		if err != nil {
			errors[id] = err
			continue
		}
		signatures[id] = sig
	}

	if len(errors) > 0 && len(signatures) == 0 {
		return nil, fmt.Errorf("all signers failed: %v", errors)
	}

	return signatures, nil
}

type ReceiptSigner struct {
	signer    Signer
	algorithm string
}

func NewReceiptSigner(signer Signer) *ReceiptSigner {
	return &ReceiptSigner{
		signer:    signer,
		algorithm: signer.Algorithm(),
	}
}

func (r *ReceiptSigner) SignReceipt(ctx context.Context, receiptID, stationID string, proof []byte, metadata map[string]string) ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString(receiptID)
	buf.WriteByte(0)
	buf.WriteString(stationID)
	buf.WriteByte(0)
	buf.Write(proof)
	buf.WriteByte(0)

	if len(metadata) > 0 {
		metaBytes, _ := NewDeterministicHasher().HashMap(metadata)
		buf.Write(metaBytes)
	}

	return r.signer.Sign(ctx, buf.Bytes())
}

func (r *ReceiptSigner) VerifyReceipt(ctx context.Context, receiptID, stationID string, proof []byte, metadata map[string]string, signature []byte) (bool, error) {
	var buf bytes.Buffer

	buf.WriteString(receiptID)
	buf.WriteByte(0)
	buf.WriteString(stationID)
	buf.WriteByte(0)
	buf.Write(proof)
	buf.WriteByte(0)

	if len(metadata) > 0 {
		metaBytes, _ := NewDeterministicHasher().HashMap(metadata)
		buf.Write(metaBytes)
	}

	return r.signer.Verify(ctx, buf.Bytes(), signature)
}

func (r *ReceiptSigner) Algorithm() string {
	return r.algorithm
}

type DeterministicHasher struct {
	hashFunc func() hash.Hash
}

func NewDeterministicHasher() *DeterministicHasher {
	return &DeterministicHasher{
		hashFunc: sha256.New,
	}
}

func (d *DeterministicHasher) HashMap(m map[string]string) ([]byte, error) {
	h := d.hashFunc()

	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}

	for i := range keys {
		for j := i + 1; j < len(keys); j++ {
			if keys[i] > keys[j] {
				keys[i], keys[j] = keys[j], keys[i]
			}
		}
	}

	for _, k := range keys {
		h.Write([]byte(k))
		h.Write([]byte{0})
		h.Write([]byte(m[k]))
		h.Write([]byte{0})
	}

	return h.Sum(nil), nil
}

func SHA256(data []byte) []byte {
	h := sha256.Sum256(data)
	return h[:]
}

func SHA512(data []byte) []byte {
	h := sha512.Sum512(data)
	return h[:]
}

func SHA256Hex(data []byte) string {
	return hex.EncodeToString(SHA256(data))
}

func SHA512Hex(data []byte) string {
	return hex.EncodeToString(SHA512(data))
}
