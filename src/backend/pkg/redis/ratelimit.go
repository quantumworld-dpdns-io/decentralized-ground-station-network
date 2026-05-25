package redis

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	ErrRateLimitExceeded = errors.New("rate limit exceeded")
)

type SlidingWindowLimiter struct {
	client    *redis.Client
	limit     int
	window    time.Duration
	prefix    string
}

type RateLimitResult struct {
	Allowed     bool
	Remaining   int
	Limit       int
	Reset       time.Time
	RetryAfter  time.Duration
}

type SlidingWindowConfig struct {
	Addr      string
	Password  string
	DB        int
	Limit     int
	Window    time.Duration
	Prefix    string
	PoolSize  int
}

func DefaultSlidingWindowConfig() *SlidingWindowConfig {
	return &SlidingWindowConfig{
		Addr:     "localhost:6379",
		Password: "",
		DB:       0,
		Limit:    100,
		Window:   time.Minute,
		Prefix:   "dgsn:ratelimit:",
		PoolSize: 10,
	}
}

func NewSlidingWindowLimiter(config *SlidingWindowConfig) *SlidingWindowLimiter {
	if config == nil {
		config = DefaultSlidingWindowConfig()
	}

	client := redis.NewClient(&redis.Options{
		Addr:     config.Addr,
		Password: config.Password,
		DB:       config.DB,
		PoolSize: config.PoolSize,
	})

	return &SlidingWindowLimiter{
		client: client,
		limit:  config.Limit,
		window: config.Window,
		prefix: config.Prefix,
	}
}

func NewSlidingWindowLimiterFromClient(client *redis.Client, limit int, window time.Duration, prefix string) *SlidingWindowLimiter {
	if client == nil {
		return nil
	}
	if prefix == "" {
		prefix = "dgsn:ratelimit:"
	}
	return &SlidingWindowLimiter{
		client: client,
		limit:  limit,
		window: window,
		prefix: prefix,
	}
}

func (l *SlidingWindowLimiter) key(k string) string {
	return l.prefix + k
}

const slidingWindowScript = `
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local unique_id = ARGV[4]

local window_start = now - window

redis.call('ZREMRANGEBYSCORE', key, '-inf', window_start)

local count = redis.call('ZCARD', key)

if count >= limit then
    local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
    if #oldest > 0 then
        local oldest_time = tonumber(oldest[2])
        local retry_after = (oldest_time + window - now) / 1000
        return {0, count, limit, retry_after}
    end
    return {0, count, limit, window / 1000}
end

redis.call('ZADD', key, now, unique_id)
redis.call('PEXPIRE', key, window)

local new_count = redis.call('ZCARD', key)
local remaining = limit - new_count

return {1, new_count, limit, 0}
`

func (l *SlidingWindowLimiter) Allow(ctx context.Context, key string) (*RateLimitResult, error) {
	now := time.Now()
	nowMs := now.UnixMilli()
	windowMs := l.window.Milliseconds()
	uniqueID := fmt.Sprintf("%d-%s", nowMs, randString(8))

	keys := []string{l.key(key)}
	argv := []interface{}{
		l.limit,
		windowMs,
		nowMs,
		uniqueID,
	}

	result, err := l.client.Eval(ctx, slidingWindowScript, keys, argv...).Result()
	if err != nil {
		return nil, fmt.Errorf("executing rate limit script: %w", err)
	}

	results, ok := result.([]interface{})
	if !ok || len(results) < 4 {
		return nil, fmt.Errorf("unexpected script result format")
	}

	allowed, _ := results[0].(int64)
	count, _ := results[1].(int64)
	limit, _ := results[2].(int64)
	retryAfterVal, _ := results[3].(int64)

	remaining := int(limit - count)
	if remaining < 0 {
		remaining = 0
	}

	reset := now.Add(l.window)
	retryAfter := time.Duration(retryAfterVal) * time.Millisecond

	return &RateLimitResult{
		Allowed:    allowed == 1,
		Remaining:  remaining,
		Limit:      int(limit),
		Reset:      reset,
		RetryAfter: retryAfter,
	}, nil
}

func (l *SlidingWindowLimiter) AllowN(ctx context.Context, key string, n int) (*RateLimitResult, error) {
	if n <= 0 {
		return &RateLimitResult{
			Allowed:   true,
			Remaining: l.limit,
			Limit:     l.limit,
			Reset:     time.Now().Add(l.window),
		}, nil
	}

	for i := 0; i < n; i++ {
		result, err := l.Allow(ctx, key)
		if err != nil {
			return nil, err
		}
		if !result.Allowed {
			return result, nil
		}
		if i == n-1 {
			return result, nil
		}
	}

	return l.Get(ctx, key)
}

func (l *SlidingWindowLimiter) Get(ctx context.Context, key string) (*RateLimitResult, error) {
	redisKey := l.key(key)
	now := time.Now()
	windowStart := now.Add(-l.window)

	if err := l.client.ZRemRangeByScore(ctx, redisKey, "-inf", fmt.Sprintf("%d", windowStart.UnixMilli())).Err(); err != nil {
		return nil, fmt.Errorf("cleaning expired entries: %w", err)
	}

	count, err := l.client.ZCard(ctx, redisKey).Result()
	if err != nil {
		return nil, fmt.Errorf("getting count: %w", err)
	}

	remaining := l.limit - int(count)
	if remaining < 0 {
		remaining = 0
	}

	reset := now.Add(l.window)

	return &RateLimitResult{
		Allowed:   remaining > 0,
		Remaining: remaining,
		Limit:     l.limit,
		Reset:     reset,
	}, nil
}

func (l *SlidingWindowLimiter) Reset(ctx context.Context, key string) error {
	if err := l.client.Del(ctx, l.key(key)).Err(); err != nil {
		return fmt.Errorf("resetting rate limit: %w", err)
	}
	return nil
}

func (l *SlidingWindowLimiter) Ping(ctx context.Context) error {
	return l.client.Ping(ctx).Err()
}

func (l *SlidingWindowLimiter) Client() *redis.Client {
	return l.client
}

func (l *SlidingWindowLimiter) Close() error {
	return l.client.Close()
}

type FixedWindowLimiter struct {
	client *redis.Client
	limit  int
	window time.Duration
	prefix string
}

func NewFixedWindowLimiter(client *redis.Client, limit int, window time.Duration, prefix string) *FixedWindowLimiter {
	if prefix == "" {
		prefix = "dgsn:ratelimit:fixed:"
	}
	return &FixedWindowLimiter{
		client: client,
		limit:  limit,
		window: window,
		prefix: prefix,
	}
}

func (l *FixedWindowLimiter) windowKey(key string) string {
	now := time.Now()
	windowStart := now.Truncate(l.window)
	return fmt.Sprintf("%s%s:%d", l.prefix, key, windowStart.Unix())
}

func (l *FixedWindowLimiter) Allow(ctx context.Context, key string) (*RateLimitResult, error) {
	redisKey := l.windowKey(key)

	pipe := l.client.Pipeline()
	incr := pipe.Incr(ctx, redisKey)
	pipe.Expire(ctx, redisKey, l.window)

	_, err := pipe.Exec(ctx)
	if err != nil {
		return nil, fmt.Errorf("executing pipeline: %w", err)
	}

	count := incr.Val()
	remaining := l.limit - int(count)
	if remaining < 0 {
		remaining = 0
	}

	allowed := count <= int64(l.limit)

	now := time.Now()
	reset := now.Truncate(l.window).Add(l.window)

	var retryAfter time.Duration
	if !allowed {
		retryAfter = reset.Sub(now)
	}

	return &RateLimitResult{
		Allowed:    allowed,
		Remaining:  remaining,
		Limit:      l.limit,
		Reset:      reset,
		RetryAfter: retryAfter,
	}, nil
}

func (l *FixedWindowLimiter) Get(ctx context.Context, key string) (*RateLimitResult, error) {
	redisKey := l.windowKey(key)

	count, err := l.client.Get(ctx, redisKey).Int64()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return &RateLimitResult{
				Allowed:   true,
				Remaining: l.limit,
				Limit:     l.limit,
				Reset:     time.Now().Truncate(l.window).Add(l.window),
			}, nil
		}
		return nil, fmt.Errorf("getting count: %w", err)
	}

	remaining := l.limit - int(count)
	if remaining < 0 {
		remaining = 0
	}

	return &RateLimitResult{
		Allowed:   remaining > 0,
		Remaining: remaining,
		Limit:     l.limit,
		Reset:     time.Now().Truncate(l.window).Add(l.window),
	}, nil
}

func randString(n int) string {
	const letterBytes = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, n)
	now := time.Now().UnixNano()
	for i := range b {
		b[i] = letterBytes[(now+int64(i))%int64(len(letterBytes))]
	}
	return string(b)
}

type TokenBucketLimiter struct {
	client     *redis.Client
	rate       float64
	capacity   int
	prefix     string
}

type TokenBucketState struct {
	Tokens      float64   `json:"tokens"`
	LastUpdated time.Time `json:"last_updated"`
}

func NewTokenBucketLimiter(client *redis.Client, rate float64, capacity int, prefix string) *TokenBucketLimiter {
	if prefix == "" {
		prefix = "dgsn:ratelimit:bucket:"
	}
	return &TokenBucketLimiter{
		client:   client,
		rate:     rate,
		capacity: capacity,
		prefix:   prefix,
	}
}

func (l *TokenBucketLimiter) Allow(ctx context.Context, key string) (*RateLimitResult, error) {
	return l.AllowN(ctx, key, 1)
}

func (l *TokenBucketLimiter) AllowN(ctx context.Context, key string, tokens int) (*RateLimitResult, error) {
	redisKey := l.prefix + key
	now := time.Now()

	data, err := l.client.Get(ctx, redisKey).Bytes()
	if err != nil && !errors.Is(err, redis.Nil) {
		return nil, fmt.Errorf("getting bucket state: %w", err)
	}

	var state TokenBucketState
	if errors.Is(err, redis.Nil) {
		state = TokenBucketState{
			Tokens:      float64(l.capacity),
			LastUpdated: now,
		}
	} else {
		if err := json.Unmarshal(data, &state); err != nil {
			return nil, fmt.Errorf("unmarshaling bucket state: %w", err)
		}

		elapsed := now.Sub(state.LastUpdated).Seconds()
		state.Tokens = minFloat(float64(l.capacity), state.Tokens+elapsed*l.rate)
		state.LastUpdated = now
	}

	allowed := state.Tokens >= float64(tokens)
	var retryAfter time.Duration

	if allowed {
		state.Tokens -= float64(tokens)
	} else {
		required := float64(tokens) - state.Tokens
		retryAfter = time.Duration(required/l.rate) * time.Second
	}

	stateData, err := json.Marshal(state)
	if err != nil {
		return nil, fmt.Errorf("marshaling bucket state: %w", err)
	}

	ttl := time.Duration(float64(l.capacity)/l.rate*2) * time.Second
	if err := l.client.Set(ctx, redisKey, stateData, ttl).Err(); err != nil {
		return nil, fmt.Errorf("saving bucket state: %w", err)
	}

	remaining := int(state.Tokens)
	if remaining < 0 {
		remaining = 0
	}

	reset := now.Add(time.Duration((float64(l.capacity)-state.Tokens)/l.rate) * time.Second)

	return &RateLimitResult{
		Allowed:    allowed,
		Remaining:  remaining,
		Limit:      l.capacity,
		Reset:      reset,
		RetryAfter: retryAfter,
	}, nil
}

func minFloat(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}
