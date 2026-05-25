package api

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/quantumworld-dpdns-io/dgsn/internal/config"
	"github.com/quantumworld-dpdns-io/dgsn/internal/middleware"
)

type Router struct {
	handlers *Handlers
	cfg      *config.Config
	logger   *slog.Logger
	mux      *http.ServeMux
}

func NewRouter(handlers *Handlers, cfg *config.Config, logger *slog.Logger) *Router {
	if logger == nil {
		logger = slog.Default()
	}
	return &Router{
		handlers: handlers,
		cfg:      cfg,
		logger:   logger,
		mux:      http.NewServeMux(),
	}
}

func (r *Router) Build() http.Handler {
	r.registerRoutes()

	baseHandler := r.mux

	baseHandler = middleware.NewCORSMiddleware(&middleware.CORSConfig{
		AllowedOrigins:   r.cfg.HTTP.AllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization", "X-Request-ID", "X-API-Key"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: false,
		MaxAge:           86400,
	}).CORS(baseHandler)

	baseHandler = middleware.NewRecoveryMiddleware(r.logger).Recovery(baseHandler)

	baseHandler = middleware.NewLoggingMiddleware(r.logger).Logging(baseHandler)

	baseHandler = middleware.NewMetricsMiddleware().Metrics(baseHandler)

	baseHandler = middleware.NewRateLimitMiddleware(nil, nil).RateLimit(baseHandler)

	return baseHandler
}

func (r *Router) registerRoutes() {
	apiV1 := "/api/v1"

	r.mux.HandleFunc("GET /healthz", r.handlers.Health.Liveness)
	r.mux.HandleFunc("GET /readyz", r.handlers.Health.Readiness)

	authMW := middleware.NewAuthMiddleware(nil, nil, r.logger)
	validMW := middleware.NewValidationMiddleware()

	stationsGroup := apiV1 + "/stations"
	r.mux.Handle("POST "+stationsGroup,
		authMW.JWTAuth(http.HandlerFunc(
			validMW.ValidateBody(&stations.RegisterStationInput{})(
				http.HandlerFunc(r.handlers.Stations.Register)).ServeHTTP)))
	r.mux.Handle("GET "+stationsGroup,
		authMW.OptionalAuth(http.HandlerFunc(r.handlers.Stations.List)))
	r.mux.Handle("GET "+stationsGroup+"/{id}",
		authMW.OptionalAuth(http.HandlerFunc(r.handlers.Stations.Get)))
	r.mux.Handle("PUT "+stationsGroup+"/{id}",
		authMW.JWTAuth(http.HandlerFunc(
			validMW.ValidateBody(&stations.UpdateStationInput{})(
				http.HandlerFunc(r.handlers.Stations.Update)).ServeHTTP)))
	r.mux.Handle("DELETE "+stationsGroup+"/{id}",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Stations.Delete)))
	r.mux.Handle("PATCH "+stationsGroup+"/{id}/status",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Stations.UpdateStatus)))

	receiptsGroup := apiV1 + "/receipts"
	r.mux.Handle("POST "+receiptsGroup,
		authMW.JWTAuth(http.HandlerFunc(
			validMW.ValidateBody(&receipts.CreateReceiptInput{})(
				http.HandlerFunc(r.handlers.Receipts.Create)).ServeHTTP)))
	r.mux.Handle("GET "+receiptsGroup,
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Receipts.List)))
	r.mux.Handle("GET "+receiptsGroup+"/{id}",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Receipts.Get)))
	r.mux.Handle("POST "+receiptsGroup+"/verify",
		authMW.JWTAuth(http.HandlerFunc(
			validMW.ValidateBody(&receipts.VerifyReceiptInput{})(
				http.HandlerFunc(r.handlers.Receipts.Verify)).ServeHTTP)))
	r.mux.Handle("POST "+receiptsGroup+"/export",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Receipts.Export)))

	scheduleGroup := apiV1 + "/schedule"
	r.mux.Handle("POST "+scheduleGroup+"/slots",
		authMW.JWTAuth(http.HandlerFunc(
			validMW.ValidateBody(&scheduling.CreateSlotInput{})(
				http.HandlerFunc(r.handlers.Schedule.CreateSlot)).ServeHTTP)))
	r.mux.Handle("GET "+scheduleGroup+"/slots",
		authMW.OptionalAuth(http.HandlerFunc(r.handlers.Schedule.GetSchedule)))
	r.mux.Handle("GET "+scheduleGroup+"/slots/{id}",
		authMW.OptionalAuth(http.HandlerFunc(r.handlers.Schedule.GetSlot)))
	r.mux.Handle("POST "+scheduleGroup+"/slots/{id}/assign",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Schedule.AssignStation)))
	r.mux.Handle("POST "+scheduleGroup+"/slots/{id}/release",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Schedule.ReleaseSlot)))
	r.mux.Handle("GET "+scheduleGroup+"/conflicts",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Schedule.ListConflicts)))

	quantumGroup := apiV1 + "/quantum"
	r.mux.Handle("POST "+quantumGroup+"/circuits",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Quantum.SubmitCircuit)))
	r.mux.Handle("GET "+quantumGroup+"/circuits",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Quantum.ListCircuits)))
	r.mux.Handle("GET "+quantumGroup+"/circuits/{id}",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Quantum.GetCircuitResult)))
	r.mux.Handle("GET "+quantumGroup+"/circuits/{id}/status",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Quantum.GetCircuitStatus)))
	r.mux.Handle("POST "+quantumGroup+"/estimate",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Quantum.EstimateCost)))

	signalsGroup := apiV1 + "/signals"
	r.mux.Handle("POST "+signalsGroup+"/upload",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Signal.UploadCapture)))
	r.mux.Handle("GET "+signalsGroup,
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Signal.ListSignals)))
	r.mux.Handle("GET "+signalsGroup+"/{id}",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Signal.GetSignal)))
	r.mux.Handle("POST "+signalsGroup+"/{id}/process",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Signal.ProcessSignal)))
	r.mux.Handle("GET "+signalsGroup+"/{id}/metrics",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Signal.GetSignalMetrics)))
	r.mux.Handle("POST "+signalsGroup+"/correlate",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Signal.CorrelateSignals)))
	r.mux.Handle("GET "+signalsGroup+"/{id}/quality",
		authMW.JWTAuth(http.HandlerFunc(r.handlers.Signal.GetSignalQuality)))
}

func JSONResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if data != nil {
		json.NewEncoder(w).Encode(data)
	}
}

func JSONError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error": message,
		"code":  status,
	})
}

func JSONErrorWithDetails(w http.ResponseWriter, status int, message string, details interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error":   message,
		"code":    status,
		"details": details,
	})
}

func GetPagination(r *http.Request, defaultLimit, maxLimit int) (limit, offset int) {
	query := r.URL.Query()

	limit = defaultLimit
	if l := query.Get("limit"); l != "" {
		if _, err := json.Number(l).Int64(); err == nil {
			var parsed int
			if json.Unmarshal([]byte(l), &parsed) == nil && parsed > 0 {
				limit = parsed
			}
		}
	}
	if limit > maxLimit {
		limit = maxLimit
	}

	offset = 0
	if o := query.Get("offset"); o != "" {
		if _, err := json.Number(o).Int64(); err == nil {
			var parsed int
			if json.Unmarshal([]byte(o), &parsed) == nil && parsed > 0 {
				offset = parsed
			}
		}
	}

	return limit, offset
}

func GetOwnerID(r *http.Request) string {
	return middleware.GetOwnerIDFromContext(r.Context())
}
