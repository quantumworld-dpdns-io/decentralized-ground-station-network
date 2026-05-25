package identity

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/dgsn/pkg/crypto"
)

var (
	ErrUserNotFound       = errors.New("user not found")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrEmailTaken         = errors.New("email already registered")
	ErrUsernameTaken      = errors.New("username already taken")
	ErrSessionExpired     = errors.New("session expired")
	ErrInvalidToken       = errors.New("invalid token")
	ErrMFARequired        = errors.New("MFA code required")
)

type UserRepository interface {
	Create(ctx context.Context, user *User) error
	GetByID(ctx context.Context, id string) (*User, error)
	GetByEmail(ctx context.Context, email string) (*User, error)
	List(ctx context.Context, filter UserFilter) ([]*User, error)
	Update(ctx context.Context, user *User) error
	Delete(ctx context.Context, id string) error
}

type SessionRepository interface {
	Create(ctx context.Context, session *Session) error
	GetByToken(ctx context.Context, token string) (*Session, error)
	Revoke(ctx context.Context, id string) error
	RevokeByUser(ctx context.Context, userID string) error
	Cleanup(ctx context.Context) error
}

type APIKeyRepository interface {
	Create(ctx context.Context, key *APIKey) error
	GetByID(ctx context.Context, id string) (*APIKey, error)
	GetByKeyHash(ctx context.Context, hash string) (*APIKey, error)
	ListByUser(ctx context.Context, userID string) ([]*APIKey, error)
	Update(ctx context.Context, key *APIKey) error
	Revoke(ctx context.Context, id string) error
}

type IdentityService interface {
	Register(ctx context.Context, input RegisterUserInput) (*User, error)
	Login(ctx context.Context, input LoginInput) (*TokenResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*TokenResponse, error)
	Logout(ctx context.Context, sessionID string) error
	ValidateToken(ctx context.Context, token string) (*User, error)
	GetUser(ctx context.Context, id string) (*User, error)
	UpdateUser(ctx context.Context, id string, updates map[string]interface{}) (*User, error)
	CreateAPIKey(ctx context.Context, userID, name string, role UserRole) (*APIKey, string, error)
	RevokeAPIKey(ctx context.Context, keyID string) error
	ValidateAPIKey(ctx context.Context, key string) (*User, error)
}

type service struct {
	userRepo    UserRepository
	sessionRepo SessionRepository
	apiKeyRepo  APIKeyRepository
	signer      crypto.Signer
	jwtSecret   []byte
}

func NewService(userRepo UserRepository, sessionRepo SessionRepository, apiKeyRepo APIKeyRepository, signer crypto.Signer, jwtSecret string) IdentityService {
	return &service{
		userRepo:    userRepo,
		sessionRepo: sessionRepo,
		apiKeyRepo:  apiKeyRepo,
		signer:      signer,
		jwtSecret:   []byte(jwtSecret),
	}
}

func (s *service) Register(ctx context.Context, input RegisterUserInput) (*User, error) {
	if existing, _ := s.userRepo.GetByEmail(ctx, input.Email); existing != nil {
		return nil, fmt.Errorf("%w: %s", ErrEmailTaken, input.Email)
	}

	user := &User{
		ID:        uuid.New().String(),
		Email:     input.Email,
		Username:  input.Username,
		Role:      RoleViewer,
		IsActive:  true,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("creating user: %w", err)
	}

	return user, nil
}

func (s *service) Login(ctx context.Context, input LoginInput) (*TokenResponse, error) {
	user, err := s.userRepo.GetByEmail(ctx, input.Email)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrInvalidCredentials, input.Email)
	}

	if !user.IsActive {
		return nil, fmt.Errorf("user account is deactivated")
	}

	if user.MFAEnabled && input.MFACode == "" {
		return nil, ErrMFARequired
	}

	token, err := s.generateToken(user)
	if err != nil {
		return nil, fmt.Errorf("generating token: %w", err)
	}

	refreshToken, err := s.generateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("generating refresh token: %w", err)
	}

	session := &Session{
		ID:           uuid.New().String(),
		UserID:       user.ID,
		Token:        token,
		RefreshToken: refreshToken,
		ExpiresAt:    time.Now().UTC().Add(24 * time.Hour),
		CreatedAt:    time.Now().UTC(),
	}

	if err := s.sessionRepo.Create(ctx, session); err != nil {
		return nil, fmt.Errorf("creating session: %w", err)
	}

	now := time.Now().UTC()
	user.LastLoginAt = &now
	s.userRepo.Update(ctx, user)

	return &TokenResponse{
		AccessToken:  token,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    86400,
	}, nil
}

func (s *service) RefreshToken(ctx context.Context, refreshToken string) (*TokenResponse, error) {
	session, err := s.sessionRepo.GetByToken(ctx, refreshToken)
	if err != nil {
		return nil, fmt.Errorf("%w: invalid refresh token", ErrInvalidToken)
	}

	if session.ExpiresAt.Before(time.Now()) {
		return nil, ErrSessionExpired
	}

	user, err := s.userRepo.GetByID(ctx, session.UserID)
	if err != nil {
		return nil, fmt.Errorf("getting user: %w", err)
	}

	token, err := s.generateToken(user)
	if err != nil {
		return nil, fmt.Errorf("generating token: %w", err)
	}

	newRefreshToken, err := s.generateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("generating refresh token: %w", err)
	}

	session.Token = token
	session.RefreshToken = newRefreshToken
	session.ExpiresAt = time.Now().UTC().Add(24 * time.Hour)
	s.sessionRepo.Create(ctx, session)

	return &TokenResponse{
		AccessToken:  token,
		RefreshToken: newRefreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    86400,
	}, nil
}

func (s *service) Logout(ctx context.Context, sessionID string) error {
	if err := s.sessionRepo.Revoke(ctx, sessionID); err != nil {
		return fmt.Errorf("revoking session: %w", err)
	}
	return nil
}

func (s *service) ValidateToken(ctx context.Context, token string) (*User, error) {
	session, err := s.sessionRepo.GetByToken(ctx, token)
	if err != nil {
		return nil, fmt.Errorf("%w: session not found", ErrInvalidToken)
	}

	if session.IsRevoked {
		return nil, fmt.Errorf("%w: session revoked", ErrInvalidToken)
	}

	if session.ExpiresAt.Before(time.Now()) {
		return nil, ErrSessionExpired
	}

	user, err := s.userRepo.GetByID(ctx, session.UserID)
	if err != nil {
		return nil, fmt.Errorf("getting user: %w", err)
	}

	return user, nil
}

func (s *service) GetUser(ctx context.Context, id string) (*User, error) {
	user, err := s.userRepo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting user: %w", err)
	}
	return user, nil
}

func (s *service) UpdateUser(ctx context.Context, id string, updates map[string]interface{}) (*User, error) {
	user, err := s.userRepo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting user for update: %w", err)
	}

	if v, ok := updates["display_name"]; ok {
		if name, ok := v.(string); ok {
			user.DisplayName = name
		}
	}
	if v, ok := updates["role"]; ok {
		if role, ok := v.(UserRole); ok {
			user.Role = role
		}
	}
	user.UpdatedAt = time.Now().UTC()

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("updating user: %w", err)
	}

	return user, nil
}

func (s *service) CreateAPIKey(ctx context.Context, userID, name string, role UserRole) (*APIKey, string, error) {
	keyBytes := make([]byte, 32)
	if _, err := rand.Read(keyBytes); err != nil {
		return nil, "", fmt.Errorf("generating API key: %w", err)
	}
	rawKey := hex.EncodeToString(keyBytes)
	keyHash := sha256Hex(rawKey)

	apiKey := &APIKey{
		ID:        uuid.New().String(),
		UserID:    userID,
		Name:      name,
		KeyPrefix: rawKey[:8],
		KeyHash:   keyHash,
		Role:      role,
		IsActive:  true,
		CreatedAt: time.Now().UTC(),
	}

	if err := s.apiKeyRepo.Create(ctx, apiKey); err != nil {
		return nil, "", fmt.Errorf("saving API key: %w", err)
	}

	return apiKey, rawKey, nil
}

func (s *service) RevokeAPIKey(ctx context.Context, keyID string) error {
	if err := s.apiKeyRepo.Revoke(ctx, keyID); err != nil {
		return fmt.Errorf("revoking API key: %w", err)
	}
	return nil
}

func (s *service) ValidateAPIKey(ctx context.Context, key string) (*User, error) {
	keyHash := sha256Hex(key)
	apiKey, err := s.apiKeyRepo.GetByKeyHash(ctx, keyHash)
	if err != nil {
		return nil, fmt.Errorf("%w: invalid API key", ErrInvalidToken)
	}

	if !apiKey.IsActive {
		return nil, fmt.Errorf("API key is revoked")
	}

	if apiKey.ExpiresAt != nil && apiKey.ExpiresAt.Before(time.Now()) {
		return nil, fmt.Errorf("API key has expired")
	}

	user, err := s.userRepo.GetByID(ctx, apiKey.UserID)
	if err != nil {
		return nil, fmt.Errorf("getting API key owner: %w", err)
	}

	now := time.Now().UTC()
	apiKey.LastUsed = &now
	s.apiKeyRepo.Update(ctx, apiKey)

	return user, nil
}

func (s *service) generateToken(user *User) (string, error) {
	data := fmt.Sprintf("%s:%s:%d", user.ID, user.Email, time.Now().UnixNano())
	sig, err := s.signer.Sign([]byte(data))
	if err != nil {
		return "", err
	}
	token := hex.EncodeToString(append([]byte(data), sig...))
	return token, nil
}

func (s *service) generateRefreshToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func sha256Hex(data string) string {
	h := sha256.Sum256([]byte(data))
	return hex.EncodeToString(h[:])
}
