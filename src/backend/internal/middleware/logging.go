package middleware

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
)

type loggingMiddleware struct {
	logger *slog.Logger
}

func NewLoggingMiddleware(logger *slog.Logger) *loggingMiddleware {
	if logger == nil {
		logger = slog.Default()
	}
	return &loggingMiddleware{logger: logger}
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
	written    int64
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	if rw.statusCode == 0 {
		rw.statusCode = http.StatusOK
	}
	n, err := rw.ResponseWriter.Write(b)
	rw.written += int64(n)
	return n, err
}

func (m *loggingMiddleware) Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		requestID := uuid.New().String()

		ctx := context.WithValue(r.Context(), RequestIDContextKey, requestID)
		r = r.WithContext(ctx)

		w.Header().Set("X-Request-ID", requestID)

		rw := &responseWriter{ResponseWriter: w}

		attrs := []slog.Attr{
			slog.String("request_id", requestID),
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.String("remote_addr", r.RemoteAddr),
			slog.String("user_agent", r.UserAgent()),
		}

		if referer := r.Referer(); referer != "" {
			attrs = append(attrs, slog.String("referer", referer))
		}

		m.logger.LogAttrs(r.Context(), slog.LevelInfo, "request started", attrs...)

		next.ServeHTTP(rw, r)

		duration := time.Since(start)
		status := rw.statusCode
		level := slog.LevelInfo

		switch {
		case status >= 500:
			level = slog.LevelError
		case status >= 400:
			level = slog.LevelWarn
		}

		m.logger.LogAttrs(r.Context(), level, "request completed",
			slog.String("request_id", requestID),
			slog.Int("status", status),
			slog.Int64("bytes_written", rw.written),
			slog.Duration("duration", duration),
			slog.String("duration_ms", duration.String()),
		)
	})
}

func RequestIDFromContext(ctx context.Context) string {
	if id, ok := ctx.Value(RequestIDContextKey).(string); ok {
		return id
	}
	return ""
}
