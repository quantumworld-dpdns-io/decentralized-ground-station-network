package middleware

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"sync"
	"time"
)

type RateLimiter interface {
	Allow(ctx context.Context, key string) (bool, *RateLimitInfo, error)
}

type RateLimitInfo struct {
	Limit     int
	Remaining int
	Reset     time.Time
	RetryAfter time.Duration
}

type tokenBucket struct {
	capacity   float64
	rate       float64
	tokens     float64
	lastUpdate time.Time
	mu         sync.Mutex
}

type inMemoryRateLimiter struct {
	buckets    map[string]*tokenBucket
	capacity   float64
	rate       float64
	mu         sync.RWMutex
	defaultLimit int
}

func NewInMemoryRateLimiter(requestsPerSecond float64, burst int) *inMemoryRateLimiter {
	return &inMemoryRateLimiter{
		buckets:      make(map[string]*tokenBucket),
		capacity:     float64(burst),
		rate:         requestsPerSecond,
		defaultLimit: burst,
	}
}

func (rl *inMemoryRateLimiter) getBucket(key string) *tokenBucket {
	rl.mu.RLock()
	bucket, exists := rl.buckets[key]
	rl.mu.RUnlock()

	if exists {
		return bucket
	}

	rl.mu.Lock()
	defer rl.mu.Unlock()

	bucket, exists = rl.buckets[key]
	if exists {
		return bucket
	}

	bucket = &tokenBucket{
		capacity:   rl.capacity,
		rate:       rl.rate,
		tokens:     rl.capacity,
		lastUpdate: time.Now(),
	}
	rl.buckets[key] = bucket
	return bucket
}

func (rl *inMemoryRateLimiter) Allow(ctx context.Context, key string) (bool, *RateLimitInfo, error) {
	bucket := rl.getBucket(key)
	bucket.mu.Lock()
	defer bucket.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(bucket.lastUpdate).Seconds()
	bucket.tokens = min(bucket.capacity, bucket.tokens+elapsed*bucket.rate)
	bucket.lastUpdate = now

	info := &RateLimitInfo{
		Limit:     int(bucket.capacity),
		Remaining: int(bucket.tokens),
		Reset:     now.Add(time.Duration((bucket.capacity-bucket.tokens)/time.Second),
	}

	if bucket.tokens >= 1 {
		bucket.tokens--
		info.Remaining = int(bucket.tokens)
		return true, info, nil
	}

	retryAfter := time.Duration((1 - bucket.tokens) / bucket.rate * float64(time.Second))
	info.RetryAfter = retryAfter
	return false, info, nil
}

type RateLimitConfig struct {
	RequestsPerSecond float64
	Burst           int
	HeaderLimit      int
	Whitelist       []string
}

func DefaultRateLimitConfig() *RateLimitConfig {
	return &RateLimitConfig{
		RequestsPerSecond: 100,
		Burst:           50,
		HeaderLimit:        100,
	}
}

type rateLimitMiddleware struct {
	limiter RateLimiter
	config  *RateLimitConfig
}

func NewRateLimitMiddleware(limiter RateLimiter, config *RateLimitConfig) *rateLimitMiddleware {
	if config == nil {
		config = DefaultRateLimitConfig()
	}
	if limiter == nil {
		limiter = NewInMemoryRateLimiter(config.RequestsPerSecond, config.Burst)
	}
	return &rateLimitMiddleware{limiter: limiter, config: config}
}

func (m *rateLimitMiddleware) RateLimit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := m.getKey(r)

		for _, ip := range m.config.Whitelist {
			if key == ip {
				next.ServeHTTP(w, r)
				return
			}
		}

		allowed, info, err := m.limiter.Allow(r.Context(), key)
		if err != nil {
			http.Error(w, "rate limit error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", info.Limit))
		w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", info.Remaining))
		w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", info.Reset.Unix()))

		if !allowed {
			w.Header().Set("Retry-After", fmt.Sprintf("%d", int(info.RetryAfter.Seconds())))
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			fmt.Fprintf(w, `{"error":"rate limit exceeded","retry_after":%d}`, int(info.RetryAfter.Seconds()))
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (m *rateLimitMiddleware) getKey(r *http.Request) string {
	if claims, ok := UserFromContext(r.Context()); ok {
		return "user:" + claims.UserID
	}
	if info, ok := APIKeyFromContext(r.Context()); ok {
		return "api_key:" + info.KeyID
	}

	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}

	if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
		parts := splitAndTrim(forwarded, ",")
		if len(parts) > 0 {
			return parts[0]
		}
	}

	if realIP := r.Header.Get("X-Real-IP"); realIP != "" {
		return realIP
	}

	return ip
}

func splitAndTrim(s, sep string) []string {
	var result []string
	for _, part := range strings.Split(s, sep) {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

import "strings"
