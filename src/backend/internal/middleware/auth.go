package middleware

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidToken = errors.New("invalid token")
	ErrMissingAuth = errors.New("missing authorization header")
	ErrInvalidAPIKey = errors.New("invalid api key")
)

type contextKey string

const (
	UserContextKey contextKey = "user"
	APIKeyContextKey contextKey = "api_key"
	RequestIDContextKey contextKey = "request_id"
)

type UserClaims struct {
	UserID    string   `json:"user_id"`
	Email     string   `json:"email"`
	Roles     []string `json:"roles"`
	StationID string   `json:"station_id,omitempty"`
	jwt.RegisteredClaims
}

type APIKeyValidator interface {
	ValidateAPIKey(ctx context.Context, key string) (*APIKeyInfo, error)
}

type APIKeyInfo struct {
	KeyID      string
	OwnerID    string
	StationID  string
	Permissions []string
	ExpiresAt  *time.Time
}

type JWTAuthConfig struct {
	Issuer           string
	Audience         string
	SigningKey       []byte
	SigningMethod    jwt.SigningMethod
	OIDCProviderURL  string
	RequiredScope     []string
}

func DefaultJWTAuthConfig() *JWTAuthConfig {
	return &JWTAuthConfig{
		Issuer:        "dgsn",
		Audience:      "dgsn-api",
		SigningMethod: jwt.SigningMethodHS256,
	}
}

type authMiddleware struct {
	jwtConfig    *JWTAuthConfig
	apiKeyValidator APIKeyValidator
	logger         *slog.Logger
}

func NewAuthMiddleware(jwtConfig *JWTAuthConfig, apiKeyValidator APIKeyValidator, logger *slog.Logger) *authMiddleware {
	if jwtConfig == nil {
		jwtConfig = DefaultJWTAuthConfig()
	}
	return &authMiddleware{
		jwtConfig:    jwtConfig,
		apiKeyValidator: apiKeyValidator,
		logger:         logger,
	}
}

func (m *authMiddleware) JWTAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "missing authorization header", http.StatusUnauthorized)
			return
		}

		parts := strings.SplitN(authHeader, " ")
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			http.Error(w, "invalid authorization format", http.StatusUnauthorized)
			return
		}

		tokenString := parts[1]
		claims := &UserClaims{}

		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			if token.Method.Alg() != m.jwtConfig.SigningMethod.Alg() {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return m.jwtConfig.SigningKey, nil
		})

		if err != nil {
			m.logger.Warn("jwt validation failed", "error", err)
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}

		if !token.Valid {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}

		if claims.Issuer != m.jwtConfig.Issuer {
			http.Error(w, "invalid token issuer", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), UserContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (m *authMiddleware) APIKeyAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		apiKey := r.Header.Get("X-API-Key")
		if apiKey == "" {
			apiKey = r.URL.Query().Get("api_key")
		}

		if apiKey == "" {
			http.Error(w, "missing api key", http.StatusUnauthorized)
			return
		}

		if m.apiKeyValidator == nil {
			http.Error(w, "api key validation not configured", http.StatusInternalServerError)
			return
		}

		info, err := m.apiKeyValidator.ValidateAPIKey(r.Context(), apiKey)
		if err != nil {
			m.logger.Warn("api key validation failed", "error", err)
			http.Error(w, "invalid api key", http.StatusUnauthorized)
			return
		}

		if info.ExpiresAt != nil && time.Now().After(*info.ExpiresAt) {
			http.Error(w, "api key expired", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), APIKeyContextKey, info)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (m *authMiddleware) OptionalAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		apiKey := r.Header.Get("X-API-Key")

		if authHeader != "" {
			parts := strings.SplitN(authHeader, " ")
			if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
				tokenString := parts[1]
				claims := &UserClaims{}
				token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
					return m.jwtConfig.SigningKey, nil
				})
				if err == nil && token.Valid {
					ctx := context.WithValue(r.Context(), UserContextKey, claims)
					next.ServeHTTP(w, r.WithContext(ctx))
					return
				}
			}
		}

		if apiKey != "" && m.apiKeyValidator != nil {
			info, err := m.apiKeyValidator.ValidateAPIKey(r.Context(), apiKey)
			if err == nil {
				ctx := context.WithValue(r.Context(), APIKeyContextKey, info)
				next.ServeHTTP(w, r.WithContext(ctx))
				return
			}
		}

		next.ServeHTTP(w, r)
	})
}

func (m *authMiddleware) RequireRole(roles ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := r.Context().Value(UserContextKey).(*UserClaims)
			if !ok {
				apiKeyInfo, ok := r.Context().Value(APIKeyContextKey).(*APIKeyInfo)
				if !ok {
					http.Error(w, "unauthorized", http.StatusUnauthorized)
					return
				}
				for _, required := range roles {
					for _, perm := range apiKeyInfo.Permissions {
						if perm == required {
							next.ServeHTTP(w, r)
							return
						}
					}
				}
				http.Error(w, "insufficient permissions", http.StatusForbidden)
				return
			}

			for _, required := range roles {
				for _, role := range claims.Roles {
					if role == required {
						next.ServeHTTP(w, r)
						return
					}
				}
			}

			http.Error(w, "insufficient permissions", http.StatusForbidden)
		})
	}
}

func UserFromContext(ctx context.Context) (*UserClaims, bool) {
	claims, ok := ctx.Value(UserContextKey).(*UserClaims)
	return claims, ok
}

func APIKeyFromContext(ctx context.Context) (*APIKeyInfo, bool) {
	info, ok := ctx.Value(APIKeyContextKey).(*APIKeyInfo)
	return info, ok
}

func GetOwnerIDFromContext(ctx context.Context) string {
	if claims, ok := UserFromContext(ctx); ok {
		return claims.UserID
	}
	if info, ok := APIKeyFromContext(ctx); ok {
		return info.OwnerID
	}
	return ""
}
