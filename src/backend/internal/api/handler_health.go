package api

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"runtime"
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/config"
)

type HealthHandler struct {
	logger      *slog.Logger
	cfg         *config.Config
	startTime   time.Time
	checkers    map[string]Checker
}

type Checker interface {
	Name() string
	Check(ctx context.Context) error
}

func NewHealthHandler(logger *slog.Logger, cfg *config.Config) *HealthHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &HealthHandler{
		logger:    logger,
		cfg:       cfg,
		startTime: time.Now(),
		checkers:  make(map[string]Checker),
	}
}

func NewHealthHandlerWithCheckers(logger *slog.Logger, cfg *config.Config, checkers []Checker) *HealthHandler {
	h := NewHealthHandler(logger, cfg)
	for _, c := range checkers {
		h.checkers[c.Name()] = c
	}
	return h
}

func (h *HealthHandler) AddChecker(checker Checker) {
	h.checkers[checker.Name()] = checker
}

func (h *HealthHandler) Liveness(w http.ResponseWriter, r *http.Request) {
	status := HealthStatus{
		Status:    "healthy",
		Version:   h.cfg.Version,
		Timestamp: time.Now().UTC(),
		Uptime:    time.Since(h.startTime).String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(status)
}

func (h *HealthHandler) Readiness(w http.ResponseWriter, r *http.Request) {
	status := HealthStatus{
		Status:    "healthy",
		Version:   h.cfg.Version,
		Timestamp: time.Now().UTC(),
		Uptime:    time.Since(h.startTime).String(),
		Checks:    make(map[string]CheckResult),
	}

	allHealthy := true

	for name, checker := range h.checkers {
		start := time.Now()
		err := checker.Check(r.Context())
		latency := time.Since(start).Milliseconds()

		result := CheckResult{
			Status:    "healthy",
			LatencyMs: latency,
		}

		if err != nil {
			result.Status = "unhealthy"
			result.Error = err.Error()
			allHealthy = false
			h.logger.Warn("health check failed", "checker", name, "error", err)
		}

		status.Checks[name] = result
	}

	if !allHealthy {
		status.Status = "degraded"
	}

	w.Header().Set("Content-Type", "application/json")
	if allHealthy {
		w.WriteHeader(http.StatusOK)
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	json.NewEncoder(w).Encode(status)
}

func (h *HealthHandler) Status(w http.ResponseWriter, r *http.Request) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	goroutines := runtime.NumGoroutine()
	numCPU := runtime.NumCPU()
	cgoCalls := runtime.NumCgoCall()

	status := map[string]interface{}{
		"version":   h.cfg.Version,
		"env":       h.cfg.Env,
		"timestamp": time.Now().UTC(),
		"uptime":    time.Since(h.startTime).String(),
		"memory": map[string]interface{}{
			"alloc":         m.Alloc,
			"total_alloc":   m.TotalAlloc,
			"sys":           m.Sys,
			"lookups":       m.Lookups,
			"mallocs":       m.Mallocs,
			"frees":         m.Frees,
			"heap_alloc":    m.HeapAlloc,
			"heap_sys":      m.HeapSys,
			"heap_idle":     m.HeapIdle,
			"heap_inuse":    m.HeapInuse,
			"heap_released": m.HeapReleased,
			"heap_objects":  m.HeapObjects,
			"stack_inuse":   m.StackInuse,
			"stack_sys":     m.StackSys,
			"num_gc":        m.NumGC,
			"gc_cpu_fraction": m.GCCPUFraction,
		},
		"runtime": map[string]interface{}{
			"goroutines":    goroutines,
			"num_cpu":       numCPU,
			"cgo_calls":     cgoCalls,
			"go_version":    runtime.Version(),
			"go_os":         runtime.GOOS,
			"go_arch":       runtime.GOARCH,
		},
		"config": map[string]interface{}{
			"grpc_port":     h.cfg.GRPC.Port,
			"http_port":     h.cfg.HTTP.Port,
			"log_level":     h.cfg.LogLevel,
		},
	}

	JSONResponse(w, http.StatusOK, status)
}
