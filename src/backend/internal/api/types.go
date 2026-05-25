package api

import (
	"context"
	"database/sql"
	"io"
	"mime/multipart"
	"net/http"
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/config"
	"github.com/quantumworld-dpdns-io/dgsn/internal/receipts"
	"github.com/quantumworld-dpdns-io/dgsn/internal/scheduling"
	"github.com/quantumworld-dpdns-io/dgsn/internal/signal"
	"github.com/quantumworld-dpdns-io/dgsn/internal/stations"
	"github.com/quantumworld-dpdns-io/dgsn/pkg/quantum"
)

type StationService interface {
	Register(ctx context.Context, input stations.RegisterStationInput, ownerID string) (*stations.Station, error)
	Get(ctx context.Context, id string) (*stations.Station, error)
	List(ctx context.Context, filter stations.StationFilter) ([]*stations.Station, error)
	Update(ctx context.Context, id string, input stations.UpdateStationInput) (*stations.Station, error)
	Delete(ctx context.Context, id string) error
	UpdateStatus(ctx context.Context, id string, status stations.StationStatus) error
	GetByOwner(ctx context.Context, ownerID string) ([]*stations.Station, error)
}

type ReceiptService interface {
	Create(ctx context.Context, input receipts.CreateReceiptInput) (*receipts.Receipt, error)
	Get(ctx context.Context, id string) (*receipts.Receipt, error)
	List(ctx context.Context, filter receipts.ReceiptFilter) ([]*receipts.Receipt, error)
	Verify(ctx context.Context, input receipts.VerifyReceiptInput) (*receipts.VerificationResult, error)
	Delete(ctx context.Context, id string) error
}

type ScheduleService interface {
	CreateSlot(ctx context.Context, input scheduling.CreateSlotInput, ownerID string) (*scheduling.ScheduleSlot, error)
	GetSlot(ctx context.Context, id string) (*scheduling.ScheduleSlot, error)
	ListSlots(ctx context.Context, filter scheduling.ScheduleFilter) ([]*scheduling.ScheduleSlot, error)
	UpdateSlot(ctx context.Context, id string, input scheduling.CreateSlotInput) (*scheduling.ScheduleSlot, error)
	DeleteSlot(ctx context.Context, id string) error
	AssignSlot(ctx context.Context, slotID, userID string) (*scheduling.Assignment, error)
	ReleaseSlot(ctx context.Context, slotID string) error
	FindConflicts(ctx context.Context, stationID string, from, to time.Time) ([]scheduling.Conflict, error)
	FindAvailable(ctx context.Context, from, to time.Time, capabilities []string) ([]*scheduling.ScheduleSlot, error)
}

type QuantumService interface {
	SubmitCircuit(ctx context.Context, input *quantum.CircuitSubmission) (*quantum.CircuitStatus, error)
	GetCircuitResult(ctx context.Context, id string) (*quantum.CircuitResult, error)
	GetCircuitStatus(ctx context.Context, id string) (*quantum.CircuitStatus, error)
	ListCircuits(ctx context.Context, ownerID string, limit, offset int) ([]*quantum.CircuitStatus, error)
	EstimateCost(ctx context.Context, input *quantum.CircuitSubmission) (float64, error)
}

type SignalService interface {
	Upload(ctx context.Context, input signal.UploadInput) (*signal.Signal, error)
	Get(ctx context.Context, id string) (*signal.Signal, error)
	List(ctx context.Context, stationID string, limit, offset int) ([]*signal.Signal, error)
	Process(ctx context.Context, id string) (*signal.ProcessingResults, error)
	Delete(ctx context.Context, id string) error
}

type HealthChecker interface {
	Check(ctx context.Context) *HealthStatus
	Readiness(ctx context.Context) *HealthStatus
}

type HealthStatus struct {
	Status    string            `json:"status"`
	Version   string            `json:"version"`
	Timestamp time.Time         `json:"timestamp"`
	Uptime    string            `json:"uptime,omitempty"`
	Checks    map[string]CheckResult `json:"checks,omitempty"`
}

type CheckResult struct {
	Status    string `json:"status"`
	Error     string `json:"error,omitempty"`
	LatencyMs int64  `json:"latency_ms,omitempty"`
}

type UploadedFile struct {
	File     multipart.File
	Header   *multipart.FileHeader
	Filename string
	Size     int64
}

func parseMultipartForm(r *http.Request, maxMemory int64) (*UploadedFile, error) {
	if err := r.ParseMultipartForm(maxMemory); err != nil {
		return nil, err
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		return nil, err
	}

	return &UploadedFile{
		File:     file,
		Header:   header,
		Filename: header.Filename,
		Size:     header.Size,
	}, nil
}

func saveUploadedFile(dst io.Writer, src io.Reader) (int64, error) {
	return io.Copy(dst, src)
}

type DBHealthCheck struct {
	db *sql.DB
}

func NewDBHealthCheck(db *sql.DB) *DBHealthCheck {
	return &DBHealthCheck{db: db}
}

func (c *DBHealthCheck) Name() string {
	return "database"
}

func (c *DBHealthCheck) Check(ctx context.Context) error {
	if c.db == nil {
		return context.DeadlineExceeded
	}
	return c.db.PingContext(ctx)
}

type RedisHealthCheck struct {
	pinger func(ctx context.Context) (string, error)
}

func NewRedisHealthCheck(pinger func(ctx context.Context) (string, error)) *RedisHealthCheck {
	return &RedisHealthCheck{pinger: pinger}
}

func (c *RedisHealthCheck) Name() string {
	return "redis"
}

func (c *RedisHealthCheck) Check(ctx context.Context) error {
	if c.pinger == nil {
		return context.DeadlineExceeded
	}
	_, err := c.pinger(ctx)
	return err
}
