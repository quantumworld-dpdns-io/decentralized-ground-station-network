package middleware

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests processed",
		},
		[]string{"method", "path", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
		},
		[]string{"method", "path"},
	)

	httpRequestSize = prometheus.NewSummary(
		prometheus.SummaryOpts{
			Name: "http_request_size_bytes",
			Help: "HTTP request size in bytes",
		},
	)

	httpResponseSize = prometheus.NewSummary(
		prometheus.SummaryOpts{
			Name: "http_response_size_bytes",
			Help: "HTTP response size in bytes",
		},
	)

	httpErrorsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_errors_total",
			Help: "Total number of HTTP errors",
		},
		[]string{"method", "path", "status"},
	)

	httpActiveRequests = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "http_active_requests",
			Help: "Number of active HTTP requests being processed",
		},
	)
)

func init() {
	prometheus.MustRegister(
		httpRequestsTotal,
		httpRequestDuration,
		httpRequestSize,
		httpResponseSize,
		httpErrorsTotal,
		httpActiveRequests,
	)
}

type metricsMiddleware struct {
	pathMapper func(string) string
}

func NewMetricsMiddleware() *metricsMiddleware {
	return &metricsMiddleware{
		pathMapper: defaultPathMapper,
	}
}

func NewMetricsMiddlewareWithMapper(pathMapper func(string) string) *metricsMiddleware {
	if pathMapper == nil {
		pathMapper = defaultPathMapper
	}
	return &metricsMiddleware{pathMapper: pathMapper}
}

func defaultPathMapper(path string) string {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) == 0 {
		return "/"
	}

	if len(parts) >= 4 {
		if parts[0] == "api" && parts[1] == "v1" {
			switch parts[2] {
			case "stations":
				if len(parts) >= 4 && looksLikeID(parts[3]) {
					return "/api/v1/stations/:id"
				}
				return "/api/v1/stations"
			case "receipts":
				if len(parts) >= 4 && looksLikeID(parts[3]) {
					return "/api/v1/receipts/:id"
				}
				return "/api/v1/receipts"
			case "schedule", "slots":
				if len(parts) >= 4 && looksLikeID(parts[3]) {
					return "/api/v1/schedule/:id"
				}
				return "/api/v1/schedule"
			case "quantum":
				if len(parts) >= 5 && parts[3] == "circuits" && looksLikeID(parts[4]) {
					return "/api/v1/quantum/circuits/:id"
				}
				return "/api/v1/quantum"
			case "signals":
				if len(parts) >= 4 && looksLikeID(parts[3]) {
					return "/api/v1/signals/:id"
				}
				return "/api/v1/signals"
			}
		}
	}

	if path == "/metrics" || path == "/healthz" || path == "/readyz" {
		return path
	}

	return "/other"
}

func looksLikeID(s string) bool {
	if len(s) == 36 {
		return true
	}
	for _, c := range s {
		if c >= '0' && c <= '9' {
			continue
		}
		if c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F' {
			continue
		}
		if c == '-' {
			continue
		}
		return false
	}
	return len(s) > 8
}

func (m *metricsMiddleware) Metrics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		path := m.pathMapper(r.URL.Path)
		method := r.Method

		httpActiveRequests.Inc()
		defer httpActiveRequests.Dec()

		if r.ContentLength > 0 {
			httpRequestSize.Observe(float64(r.ContentLength))
		}

		rw := &metricsResponseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		next.ServeHTTP(rw, r)

		duration := time.Since(start).Seconds()
		status := strconv.Itoa(rw.statusCode)

		httpRequestsTotal.WithLabelValues(method, path, status).Inc()
		httpRequestDuration.WithLabelValues(method, path).Observe(duration)

		if rw.written > 0 {
			httpResponseSize.Observe(float64(rw.written))
		}

		if rw.statusCode >= 400 {
			httpErrorsTotal.WithLabelValues(method, path, status).Inc()
		}
	})
}

type metricsResponseWriter struct {
	http.ResponseWriter
	statusCode int
	written    int64
}

func (rw *metricsResponseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *metricsResponseWriter) Write(b []byte) (int, error) {
	n, err := rw.ResponseWriter.Write(b)
	rw.written += int64(n)
	return n, err
}
