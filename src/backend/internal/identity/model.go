package identity

import (
	"time"
)

type UserRole string

const (
	RoleAdmin     UserRole = "admin"
	RoleOperator  UserRole = "operator"
	RoleOwner     UserRole = "owner"
	RoleViewer    UserRole = "viewer"
)

type MFAType string

const (
	MFATypeTOTP   MFAType = "totp"
	MFATypeSMS    MFAType = "sms"
	MFATypeEmail  MFAType = "email"
	MFATypeWebAuthn MFAType = "webauthn"
)

type User struct {
	ID             string            `json:"id"`
	Email          string            `json:"email"`
	Username       string            `json:"username"`
	DisplayName    string            `json:"display_name,omitempty"`
	Role           UserRole          `json:"role"`
	DID            string            `json:"did,omitempty"`
	PublicKey      string            `json:"public_key,omitempty"`
	MFAEnabled     bool              `json:"mfa_enabled"`
	MFAType        MFAType           `json:"mfa_type,omitempty"`
	EmailVerified  bool              `json:"email_verified"`
	IsActive       bool              `json:"is_active"`
	Metadata       map[string]string `json:"metadata,omitempty"`
	LastLoginAt    *time.Time        `json:"last_login_at,omitempty"`
	CreatedAt      time.Time         `json:"created_at"`
	UpdatedAt      time.Time         `json:"updated_at"`
}

type Session struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	Token       string    `json:"token"`
	RefreshToken string   `json:"refresh_token,omitempty"`
	IPAddress   string    `json:"ip_address,omitempty"`
	UserAgent   string    `json:"user_agent,omitempty"`
	ExpiresAt   time.Time `json:"expires_at"`
	CreatedAt   time.Time `json:"created_at"`
	IsRevoked   bool      `json:"is_revoked"`
}

type APIKey struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	KeyPrefix string    `json:"key_prefix"`
	KeyHash   string    `json:"-"`
	Role      UserRole  `json:"role"`
	IsActive  bool      `json:"is_active"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
	LastUsed  *time.Time `json:"last_used,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type RegisterUserInput struct {
	Email    string `json:"email" validate:"required,email"`
	Username string `json:"username" validate:"required,min=3,max=50"`
	Password string `json:"password" validate:"required,min=8"`
}

type LoginInput struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
	MFACode  string `json:"mfa_code,omitempty"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
	Scope        string `json:"scope,omitempty"`
}

type UserFilter struct {
	Role     *UserRole `json:"role,omitempty"`
	IsActive *bool     `json:"is_active,omitempty"`
	Limit    int       `json:"limit,omitempty"`
	Offset   int       `json:"offset,omitempty"`
}
