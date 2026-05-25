package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"
)

type recoveryMiddleware struct {
	logger        *slog.Logger
	stackTraceAll bool
}

func NewRecoveryMiddleware(logger *slog.Logger) *recoveryMiddleware {
	if logger == nil {
		logger = slog.Default()
	}
	return &recoveryMiddleware{
		logger:        logger,
		stackTraceAll: true,
	}
}

func NewRecoveryMiddlewareWithOptions(logger *slog.Logger, stackTraceAll bool) *recoveryMiddleware {
	if logger == nil {
		logger = slog.Default()
	}
	return &recoveryMiddleware{
		logger:        logger,
		stackTraceAll: stackTraceAll,
	}
}

func (m *recoveryMiddleware) Recovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				stack := debug.Stack()

				requestID := RequestIDFromContext(r.Context())

				m.logger.Error("panic recovered",
					slog.Any("panic", rec),
					slog.String("request_id", requestID),
					slog.String("method", r.Method),
					slog.String("path", r.URL.Path),
					slog.String("remote_addr", r.RemoteAddr),
					slog.String("stack", string(stack)),
				)

				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusInternalServerError)

				errorMsg := "Internal Server Error"
				if m.stackTraceAll {
					errorMsg = "Internal Server Error - check logs for details"
				}

				response := `{"error":"` + escapeJSON(errorMsg) + `","request_id":"` + escapeJSON(requestID) + `"}`
				w.Write([]byte(response))
			}
		}()

		next.ServeHTTP(w, r)
	})
}

func escapeJSON(s string) string {
	result := ""
	for _, c := range s {
		switch c {
		case '"':
			result += "\\\""
		case '\\':
			result += "\\\\"
		case '\n':
			result += "\\n"
		case '\r':
			result += "\\r"
		case '\t':
			result += "\\t"
		default:
			if c < 32 {
				result += "\\u00" + string("0123456789abcdef"[c>>4]) + string("0123456789abcdef"[c&0xf])
			} else {
				result += string(c)
			}
		}
	}
	return result
}
