package observability

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

type AuditAction string

const (
	AuditActionCreate   AuditAction = "create"
	AuditActionUpdate   AuditAction = "update"
	AuditActionDelete   AuditAction = "delete"
	AuditActionLogin    AuditAction = "login"
	AuditActionLogout   AuditAction = "logout"
	AuditActionVerify   AuditAction = "verify"
	AuditActionSchedule AuditAction = "schedule"
	AuditActionUpload   AuditAction = "upload"
	AuditActionProcess  AuditAction = "process"
)

type AlertSeverity string

const (
	AlertSeverityInfo     AlertSeverity = "info"
	AlertSeverityWarning  AlertSeverity = "warning"
	AlertSeverityError    AlertSeverity = "error"
	AlertSeverityCritical AlertSeverity = "critical"
)

type AuditEntry struct {
	ID          string            `json:"id"`
	Action      AuditAction       `json:"action"`
	ResourceType string           `json:"resource_type"`
	ResourceID  string            `json:"resource_id,omitempty"`
	UserID      string            `json:"user_id,omitempty"`
	Description string            `json:"description"`
	Metadata    map[string]string `json:"metadata,omitempty"`
	IPAddress   string            `json:"ip_address,omitempty"`
	CreatedAt   time.Time         `json:"created_at"`
}

type Alert struct {
	ID          string            `json:"id"`
	Title       string            `json:"title"`
	Message     string            `json:"message"`
	Severity    AlertSeverity     `json:"severity"`
	Source      string            `json:"source"`
	ResourceID  string            `json:"resource_id,omitempty"`
	Metadata    map[string]string `json:"metadata,omitempty"`
	Acknowledged bool             `json:"acknowledged"`
	AckedBy     string            `json:"acked_by,omitempty"`
	CreatedAt   time.Time         `json:"created_at"`
	AckedAt     *time.Time        `json:"acked_at,omitempty"`
}

type MetricsSnapshot struct {
	ActiveStations  int     `json:"active_stations"`
	TotalReceipts   int64   `json:"total_receipts"`
	TotalSignals    int64   `json:"total_signals"`
	UpTimeSeconds   int64   `json:"uptime_seconds"`
	RequestsTotal   int64   `json:"requests_total"`
	RequestsPerSec  float64 `json:"requests_per_sec"`
	AvgLatency      float64 `json:"avg_latency_ms"`
	ErrorRate       float64 `json:"error_rate"`
	MemoryUsageMB   float64 `json:"memory_usage_mb"`
	CPUUsagePercent float64 `json:"cpu_usage_percent"`
}

type MetricsCollector interface {
	RecordRequest(method, path string, statusCode int, latency time.Duration)
	RecordStationEvent(eventType string)
	RecordReceiptEvent(eventType string)
	RecordSignalEvent(eventType string)
	RecordError(component string, err error)
	Snapshot() MetricsSnapshot
}

type AuditLogger interface {
	Log(ctx context.Context, entry AuditEntry) error
	Query(ctx context.Context, filter AuditFilter) ([]*AuditEntry, error)
}

type AlertManager interface {
	Create(ctx context.Context, alert Alert) (*Alert, error)
	Acknowledge(ctx context.Context, id, userID string) error
	List(ctx context.Context, filter AlertFilter) ([]*Alert, error)
	Resolve(ctx context.Context, id string) error
}

type AuditFilter struct {
	Action       AuditAction `json:"action,omitempty"`
	ResourceType string      `json:"resource_type,omitempty"`
	UserID       string      `json:"user_id,omitempty"`
	FromDate     *time.Time  `json:"from_date,omitempty"`
	ToDate       *time.Time  `json:"to_date,omitempty"`
	Limit        int         `json:"limit,omitempty"`
	Offset       int         `json:"offset,omitempty"`
}

type AlertFilter struct {
	Severity    AlertSeverity `json:"severity,omitempty"`
	Source      string        `json:"source,omitempty"`
	Acknowledged *bool        `json:"acknowledged,omitempty"`
	Limit       int           `json:"limit,omitempty"`
	Offset      int           `json:"offset,omitempty"`
}

type Service interface {
	MetricsCollector
	AuditLogger
	AlertManager
}

type service struct {
	mu       sync.RWMutex
	startAt time.Time

	requestsTotal prometheus.Counter
	requestLatency prometheus.Histogram
	errorsTotal   prometheus.Counter
	activeStations prometheus.Gauge

	auditLogs []*AuditEntry
	alerts    []*Alert
}

func NewService() Service {
	s := &service{
		startAt:  time.Now(),
		auditLogs: make([]*AuditEntry, 0, 1000),
		alerts:   make([]*Alert, 0, 100),
	}

	s.requestsTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "dgsn_requests_total",
		Help: "Total number of HTTP/gRPC requests",
	})
	s.requestLatency = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "dgsn_request_latency_seconds",
		Help:    "Request latency distribution",
		Buckets: prometheus.DefBuckets,
	})
	s.errorsTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "dgsn_errors_total",
		Help: "Total number of errors",
	})
	s.activeStations = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "dgsn_active_stations",
		Help: "Number of active stations",
	})

	return s
}

func (s *service) RecordRequest(method, path string, statusCode int, latency time.Duration) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.requestsTotal.Inc()
	s.requestLatency.Observe(latency.Seconds())
}

func (s *service) RecordStationEvent(eventType string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if eventType == "online" {
		s.activeStations.Inc()
	} else if eventType == "offline" {
		s.activeStations.Dec()
	}
}

func (s *service) RecordReceiptEvent(eventType string) {
}

func (s *service) RecordSignalEvent(eventType string) {
}

func (s *service) RecordError(component string, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.errorsTotal.Inc()
}

func (s *service) Snapshot() MetricsSnapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()

	snapshot := MetricsSnapshot{
		UpTimeSeconds: int64(time.Since(s.startAt).Seconds()),
	}
	return snapshot
}

func (s *service) Log(ctx context.Context, entry AuditEntry) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	entry.ID = uuid.New().String()
	if entry.CreatedAt.IsZero() {
		entry.CreatedAt = time.Now().UTC()
	}

	s.auditLogs = append(s.auditLogs, &entry)

	return nil
}

func (s *service) Query(ctx context.Context, filter AuditFilter) ([]*AuditEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var results []*AuditEntry
	for _, entry := range s.auditLogs {
		if filter.Action != "" && entry.Action != filter.Action {
			continue
		}
		if filter.ResourceType != "" && entry.ResourceType != filter.ResourceType {
			continue
		}
		if filter.UserID != "" && entry.UserID != filter.UserID {
			continue
		}
		if filter.FromDate != nil && entry.CreatedAt.Before(*filter.FromDate) {
			continue
		}
		if filter.ToDate != nil && entry.CreatedAt.After(*filter.ToDate) {
			continue
		}
		results = append(results, entry)
	}

	limit := filter.Limit
	if limit <= 0 {
		limit = 100
	}
	if len(results) > limit {
		results = results[:limit]
	}

	return results, nil
}

func (s *service) Create(ctx context.Context, alert Alert) (*Alert, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	alert.ID = uuid.New().String()
	if alert.CreatedAt.IsZero() {
		alert.CreatedAt = time.Now().UTC()
	}

	s.alerts = append(s.alerts, &alert)

	return &alert, nil
}

func (s *service) Acknowledge(ctx context.Context, id, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, alert := range s.alerts {
		if alert.ID == id {
			alert.Acknowledged = true
			alert.AckedBy = userID
			now := time.Now().UTC()
			alert.AckedAt = &now
			return nil
		}
	}
	return fmt.Errorf("alert %s not found", id)
}

func (s *service) List(ctx context.Context, filter AlertFilter) ([]*Alert, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var results []*Alert
	for _, alert := range s.alerts {
		if filter.Severity != "" && alert.Severity != filter.Severity {
			continue
		}
		if filter.Source != "" && alert.Source != filter.Source {
			continue
		}
		if filter.Acknowledged != nil && alert.Acknowledged != *filter.Acknowledged {
			continue
		}
		results = append(results, alert)
	}

	return results, nil
}

func (s *service) Resolve(ctx context.Context, id string) error {
	return s.Acknowledge(ctx, id, "system")
}

func FormatAuditEntryJSON(entry *AuditEntry) ([]byte, error) {
	return json.Marshal(entry)
}

func ParseAuditEntryJSON(data []byte) (*AuditEntry, error) {
	var entry AuditEntry
	if err := json.Unmarshal(data, &entry); err != nil {
		return nil, fmt.Errorf("parsing audit entry: %w", err)
	}
	return &entry, nil
}
