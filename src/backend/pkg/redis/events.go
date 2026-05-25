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
	ErrStreamNotFound  = errors.New("stream not found")
	ErrConsumerTimeout = errors.New("consumer timeout")
)

type Event struct {
	ID        string                 `json:"id"`
	Type      string                 `json:"type"`
	Source    string                 `json:"source"`
	Timestamp time.Time              `json:"timestamp"`
	Payload   map[string]interface{} `json:"payload"`
	Metadata  map[string]string      `json:"metadata,omitempty"`
}

type EventPublisher struct {
	client *redis.Client
	prefix string
}

type EventConsumer struct {
	client   *redis.Client
	stream   string
	group    string
	consumer string
	prefix   string
}

type EventConfig struct {
	Addr     string
	Password string
	DB       int
	Prefix   string
	PoolSize int
}

func DefaultEventConfig() *EventConfig {
	return &EventConfig{
		Addr:     "localhost:6379",
		Password: "",
		DB:       0,
		Prefix:   "dgsn:events:",
		PoolSize: 10,
	}
}

func NewEventPublisher(config *EventConfig) *EventPublisher {
	if config == nil {
		config = DefaultEventConfig()
	}

	client := redis.NewClient(&redis.Options{
		Addr:     config.Addr,
		Password: config.Password,
		DB:       config.DB,
		PoolSize: config.PoolSize,
	})

	return &EventPublisher{
		client: client,
		prefix: config.Prefix,
	}
}

func NewEventPublisherFromClient(client *redis.Client, prefix string) *EventPublisher {
	if prefix == "" {
		prefix = "dgsn:events:"
	}
	return &EventPublisher{
		client: client,
		prefix: prefix,
	}
}

func (p *EventPublisher) streamKey(stream string) string {
	return p.prefix + stream
}

func (p *EventPublisher) Publish(ctx context.Context, stream string, event *Event) (string, error) {
	if event == nil {
		return "", fmt.Errorf("event is nil")
	}

	if event.Timestamp.IsZero() {
		event.Timestamp = time.Now().UTC()
	}

	eventData, err := json.Marshal(event)
	if err != nil {
		return "", fmt.Errorf("marshaling event: %w", err)
	}

	values := map[string]interface{}{
		"event_type": event.Type,
		"source":     event.Source,
		"timestamp":  event.Timestamp.Format(time.RFC3339Nano),
		"data":       string(eventData),
	}

	if len(event.Metadata) > 0 {
		for k, v := range event.Metadata {
			values["meta_"+k] = v
		}
	}

	id, err := p.client.XAdd(ctx, &redis.XAddArgs{
		Stream: p.streamKey(stream),
		MaxLen: 10000,
		Approx: true,
		Values: values,
	}).Result()

	if err != nil {
		return "", fmt.Errorf("publishing event: %w", err)
	}

	return id, nil
}

func (p *EventPublisher) PublishSimple(ctx context.Context, stream, eventType string, payload map[string]interface{}) (string, error) {
	event := &Event{
		Type:      eventType,
		Source:    "publisher",
		Timestamp: time.Now().UTC(),
		Payload:   payload,
	}
	return p.Publish(ctx, stream, event)
}

func (p *EventPublisher) Ping(ctx context.Context) error {
	return p.client.Ping(ctx).Err()
}

func (p *EventPublisher) Client() *redis.Client {
	return p.client
}

func (p *EventPublisher) Close() error {
	return p.client.Close()
}

func NewEventConsumer(client *redis.Client, stream, group, consumer, prefix string) *EventConsumer {
	if prefix == "" {
		prefix = "dgsn:events:"
	}
	return &EventConsumer{
		client:   client,
		stream:   stream,
		group:    group,
		consumer: consumer,
		prefix:   prefix,
	}
}

func (c *EventConsumer) streamKey() string {
	return c.prefix + c.stream
}

func (c *EventConsumer) CreateGroup(ctx context.Context, startFrom string) error {
	if startFrom == "" {
		startFrom = "$"
	}

	err := c.client.XGroupCreateMkStream(ctx, c.streamKey(), c.group, startFrom).Err()
	if err != nil {
		if err.Error() == "BUSYGROUP Consumer Group name already exists" {
			return nil
		}
		return fmt.Errorf("creating consumer group: %w", err)
	}
	return nil
}

func (c *EventConsumer) Consume(ctx context.Context, count int, block time.Duration) ([]*Event, error) {
	streams, err := c.client.XReadGroup(ctx, &redis.XReadGroupArgs{
		Group:    c.group,
		Consumer: c.consumer,
		Streams:  []string{c.streamKey(), ">"},
		Count:    int64(count),
		Block:    block,
	}).Result()

	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, nil
		}
		return nil, fmt.Errorf("reading from stream: %w", err)
	}

	var events []*Event
	for _, stream := range streams {
		for _, msg := range stream.Messages {
			event, err := parseMessage(msg)
			if err != nil {
				continue
			}
			events = append(events, event)
		}
	}

	return events, nil
}

func (c *EventConsumer) ConsumePending(ctx context.Context, count int, idle time.Duration) ([]*Event, error) {
	streams, err := c.client.XReadGroup(ctx, &redis.XReadGroupArgs{
		Group:    c.group,
		Consumer: c.consumer,
		Streams:  []string{c.streamKey(), "0"},
		Count:    int64(count),
		Block:    0,
	}).Result()

	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, nil
		}
		return nil, fmt.Errorf("reading pending messages: %w", err)
	}

	var events []*Event
	for _, stream := range streams {
		for _, msg := range stream.Messages {
			event, err := parseMessage(msg)
			if err != nil {
				continue
			}
			events = append(events, event)
		}
	}

	return events, nil
}

func (c *EventConsumer) Ack(ctx context.Context, ids ...string) error {
	if len(ids) == 0 {
		return nil
	}

	err := c.client.XAck(ctx, c.streamKey(), c.group, ids...).Err()
	if err != nil {
		return fmt.Errorf("acking messages: %w", err)
	}
	return nil
}

func (c *EventConsumer) NAck(ctx context.Context, ids ...string) error {
	return nil
}

func (c *EventConsumer) Claim(ctx context.Context, minIdle time.Duration, ids ...string) ([]string, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	result, err := c.client.XClaim(ctx, &redis.XClaimArgs{
		Stream:   c.streamKey(),
		Group:    c.group,
		Consumer: c.consumer,
		MinIdle:  minIdle,
		Messages: ids,
	}).Result()

	if err != nil {
		return nil, fmt.Errorf("claiming messages: %w", err)
	}

	claimedIDs := make([]string, len(result))
	for i, msg := range result {
		claimedIDs[i] = msg.ID
	}

	return claimedIDs, nil
}

func (c *EventConsumer) PendingInfo(ctx context.Context) (*redis.XPending, error) {
	info, err := c.client.XPending(ctx, c.streamKey(), c.group).Result()
	if err != nil {
		return nil, fmt.Errorf("getting pending info: %w", err)
	}
	return info, nil
}

func (c *EventConsumer) Ping(ctx context.Context) error {
	return c.client.Ping(ctx).Err()
}

func (c *EventConsumer) Client() *redis.Client {
	return c.client
}

func parseMessage(msg redis.XMessage) (*Event, error) {
	dataStr, ok := msg.Values["data"].(string)
	if !ok {
		return nil, fmt.Errorf("no data field in message")
	}

	var event Event
	if err := json.Unmarshal([]byte(dataStr), &event); err != nil {
		return nil, fmt.Errorf("unmarshaling event: %w", err)
	}

	event.ID = msg.ID

	if eventType, ok := msg.Values["event_type"].(string); ok {
		event.Type = eventType
	}
	if source, ok := msg.Values["source"].(string); ok {
		event.Source = source
	}
	if ts, ok := msg.Values["timestamp"].(string); ok {
		if t, err := time.Parse(time.RFC3339Nano, ts); err == nil {
			event.Timestamp = t
		}
	}

	event.Metadata = make(map[string]string)
	for k, v := range msg.Values {
		if len(k) > 5 && k[:5] == "meta_" {
			if strVal, ok := v.(string); ok {
				event.Metadata[k[5:]] = strVal
			}
		}
	}

	return &event, nil
}

type EventBus struct {
	publisher *EventPublisher
	consumers map[string]*EventConsumer
}

func NewEventBus(publisher *EventPublisher) *EventBus {
	return &EventBus{
		publisher: publisher,
		consumers: make(map[string]*EventConsumer),
	}
}

func (b *EventBus) Publish(ctx context.Context, stream string, event *Event) (string, error) {
	return b.publisher.Publish(ctx, stream, event)
}

func (b *EventBus) Subscribe(ctx context.Context, stream, group, consumer string, handler func(*Event) error) error {
	c := NewEventConsumer(b.publisher.client, stream, group, consumer, b.publisher.prefix)

	if err := c.CreateGroup(ctx, "0"); err != nil {
		return fmt.Errorf("creating consumer group: %w", err)
	}

	b.consumers[stream+":"+group+":"+consumer] = c

	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			default:
				events, err := c.Consume(ctx, 10, 5*time.Second)
				if err != nil {
					continue
				}
				for _, event := range events {
					if err := handler(event); err == nil {
						c.Ack(ctx, event.ID)
					}
				}
			}
		}
	}()

	return nil
}
