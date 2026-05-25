package redis

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	ErrCacheMiss = errors.New("cache miss")
	ErrCacheFull = errors.New("cache full")
)

type Cache struct {
	client *redis.Client
	ttl    time.Duration
	prefix string
}

type CacheConfig struct {
	Addr     string
	Password string
	DB       int
	TTL      time.Duration
	Prefix   string
	PoolSize int
}

func DefaultCacheConfig() *CacheConfig {
	return &CacheConfig{
		Addr:     "localhost:6379",
		Password: "",
		DB:       0,
		TTL:      5 * time.Minute,
		Prefix:   "dgsn:cache:",
		PoolSize: 10,
	}
}

func NewCache(config *CacheConfig) *Cache {
	if config == nil {
		config = DefaultCacheConfig()
	}

	client := redis.NewClient(&redis.Options{
		Addr:     config.Addr,
		Password: config.Password,
		DB:       config.DB,
		PoolSize: config.PoolSize,
	})

	return &Cache{
		client: client,
		ttl:    config.TTL,
		prefix: config.Prefix,
	}
}

func NewCacheFromClient(client *redis.Client, ttl time.Duration, prefix string) *Cache {
	if client == nil {
		return nil
	}
	if prefix == "" {
		prefix = "dgsn:cache:"
	}
	return &Cache{
		client: client,
		ttl:    ttl,
		prefix: prefix,
	}
}

func (c *Cache) key(k string) string {
	return c.prefix + k
}

func (c *Cache) Get(ctx context.Context, key string, dst interface{}) error {
	data, err := c.client.Get(ctx, c.key(key)).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return ErrCacheMiss
		}
		return fmt.Errorf("getting from cache: %w", err)
	}

	if dst != nil {
		if err := json.Unmarshal(data, dst); err != nil {
			return fmt.Errorf("unmarshaling cache data: %w", err)
		}
	}

	return nil
}

func (c *Cache) Set(ctx context.Context, key string, value interface{}) error {
	return c.SetWithTTL(ctx, key, value, c.ttl)
}

func (c *Cache) SetWithTTL(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("marshaling value: %w", err)
	}

	if err := c.client.Set(ctx, c.key(key), data, ttl).Err(); err != nil {
		return fmt.Errorf("setting to cache: %w", err)
	}

	return nil
}

func (c *Cache) SetNX(ctx context.Context, key string, value interface{}, ttl time.Duration) (bool, error) {
	data, err := json.Marshal(value)
	if err != nil {
		return false, fmt.Errorf("marshaling value: %w", err)
	}

	ok, err := c.client.SetNX(ctx, c.key(key), data, ttl).Result()
	if err != nil {
		return false, fmt.Errorf("setting nx to cache: %w", err)
	}

	return ok, nil
}

func (c *Cache) Delete(ctx context.Context, keys ...string) error {
	redisKeys := make([]string, len(keys))
	for i, k := range keys {
		redisKeys[i] = c.key(k)
	}

	if err := c.client.Del(ctx, redisKeys...).Err(); err != nil {
		return fmt.Errorf("deleting from cache: %w", err)
	}

	return nil
}

func (c *Cache) Exists(ctx context.Context, key string) (bool, error) {
	count, err := c.client.Exists(ctx, c.key(key)).Result()
	if err != nil {
		return false, fmt.Errorf("checking existence: %w", err)
	}
	return count > 0, nil
}

func (c *Cache) Expire(ctx context.Context, key string, ttl time.Duration) error {
	if err := c.client.Expire(ctx, c.key(key), ttl).Err(); err != nil {
		return fmt.Errorf("setting expiration: %w", err)
	}
	return nil
}

func (c *Cache) TTL(ctx context.Context, key string) (time.Duration, error) {
	ttl, err := c.client.TTL(ctx, c.key(key)).Result()
	if err != nil {
		return 0, fmt.Errorf("getting ttl: %w", err)
	}
	return ttl, nil
}

func (c *Cache) GetMap(ctx context.Context, key string) (map[string]string, error) {
	result, err := c.client.HGetAll(ctx, c.key(key)).Result()
	if err != nil {
		return nil, fmt.Errorf("getting hash: %w", err)
	}
	return result, nil
}

func (c *Cache) SetMap(ctx context.Context, key string, values map[string]interface{}) error {
	redisValues := make(map[string]interface{})
	for k, v := range values {
		switch val := v.(type) {
		case string:
			redisValues[k] = val
		case []byte:
			redisValues[k] = string(val)
		default:
			data, err := json.Marshal(val)
			if err != nil {
				return fmt.Errorf("marshaling hash field %s: %w", k, err)
			}
			redisValues[k] = string(data)
		}
	}

	if err := c.client.HSet(ctx, c.key(key), redisValues).Err(); err != nil {
		return fmt.Errorf("setting hash: %w", err)
	}
	return nil
}

func (c *Cache) GetMapField(ctx context.Context, key, field string, dst interface{}) error {
	data, err := c.client.HGet(ctx, c.key(key), field).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return ErrCacheMiss
		}
		return fmt.Errorf("getting hash field: %w", err)
	}

	if dst != nil {
		if str, ok := dst.(*string); ok {
			*str = string(data)
			return nil
		}
		if err := json.Unmarshal(data, dst); err != nil {
			return fmt.Errorf("unmarshaling hash field: %w", err)
		}
	}

	return nil
}

func (c *Cache) SetMapField(ctx context.Context, key, field string, value interface{}) error {
	var redisValue string
	switch val := value.(type) {
	case string:
		redisValue = val
	case []byte:
		redisValue = string(val)
	default:
		data, err := json.Marshal(value)
		if err != nil {
			return fmt.Errorf("marshaling value: %w", err)
		}
		redisValue = string(data)
	}

	if err := c.client.HSet(ctx, c.key(key), field, redisValue).Err(); err != nil {
		return fmt.Errorf("setting hash field: %w", err)
	}
	return nil
}

func (c *Cache) Increment(ctx context.Context, key string) (int64, error) {
	result, err := c.client.Incr(ctx, c.key(key)).Result()
	if err != nil {
		return 0, fmt.Errorf("incrementing: %w", err)
	}
	return result, nil
}

func (c *Cache) IncrementBy(ctx context.Context, key string, delta int64) (int64, error) {
	result, err := c.client.IncrBy(ctx, c.key(key), delta).Result()
	if err != nil {
		return 0, fmt.Errorf("incrementing by: %w", err)
	}
	return result, nil
}

func (c *Cache) Decrement(ctx context.Context, key string) (int64, error) {
	result, err := c.client.Decr(ctx, c.key(key)).Result()
	if err != nil {
		return 0, fmt.Errorf("decrementing: %w", err)
	}
	return result, nil
}

func (c *Cache) Ping(ctx context.Context) error {
	return c.client.Ping(ctx).Err()
}

func (c *Cache) Client() *redis.Client {
	return c.client
}

func (c *Cache) Close() error {
	return c.client.Close()
}

func (c *Cache) Keys(ctx context.Context, pattern string) ([]string, error) {
	keys, err := c.client.Keys(ctx, c.key(pattern)).Result()
	if err != nil {
		return nil, fmt.Errorf("getting keys: %w", err)
	}

	stripped := make([]string, len(keys))
	for i, k := range keys {
		stripped[i] = k[len(c.prefix):]
	}
	return stripped, nil
}

func (c *Cache) FlushDB(ctx context.Context) error {
	return c.client.FlushDB(ctx).Err()
}
