package middleware

import (
	"net/http"
	"strconv"
	"strings"
)

type CORSConfig struct {
	AllowedOrigins   []string
	AllowedMethods   []string
	AllowedHeaders   []string
	ExposedHeaders   []string
	AllowCredentials bool
	MaxAge           int
}

func DefaultCORSConfig() *CORSConfig {
	return &CORSConfig{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization", "X-Request-ID", "X-API-Key"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: false,
		MaxAge:           86400,
	}
}

type corsMiddleware struct {
	config *CORSConfig
}

func NewCORSMiddleware(config *CORSConfig) *corsMiddleware {
	if config == nil {
		config = DefaultCORSConfig()
	}
	return &corsMiddleware{config: config}
}

func (m *corsMiddleware) CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		if origin == "" {
			next.ServeHTTP(w, r)
			return
		}

		if !m.isOriginAllowed(origin) {
			next.ServeHTTP(w, r)
			return
		}

		w.Header().Set("Access-Control-Allow-Origin", origin)

		if m.config.AllowCredentials {
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		}

		if len(m.config.ExposedHeaders) > 0 {
			w.Header().Set("Access-Control-Expose-Headers", strings.Join(m.config.ExposedHeaders, ", "))
		}

		if r.Method == http.MethodOptions {
			m.handlePreflight(w, r)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (m *corsMiddleware) handlePreflight(w http.ResponseWriter, r *http.Request) {
	reqMethod := r.Header.Get("Access-Control-Request-Method")
	reqHeaders := r.Header.Get("Access-Control-Request-Headers")

	if reqMethod != "" {
		if !m.isMethodAllowed(reqMethod) {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		w.Header().Set("Access-Control-Allow-Methods", strings.Join(m.config.AllowedMethods, ", "))
	}

	if reqHeaders != "" {
		allowed, rejected := m.checkHeaders(reqHeaders)
		if !allowed && len(rejected) > 0 {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		w.Header().Set("Access-Control-Allow-Headers", reqHeaders)
	}

	if m.config.MaxAge > 0 {
		w.Header().Set("Access-Control-Max-Age", strconv.Itoa(m.config.MaxAge))
	}

	w.WriteHeader(http.StatusNoContent)
}

func (m *corsMiddleware) isOriginAllowed(origin string) bool {
	for _, allowed := range m.config.AllowedOrigins {
		if allowed == "*" {
			return true
		}
		if strings.EqualFold(allowed, origin) {
			return true
		}
		if strings.HasPrefix(allowed, "*.") {
			domain := allowed[1:]
			if strings.HasSuffix(strings.ToLower(origin), strings.ToLower(domain)) {
				return true
			}
		}
	}
	return false
}

func (m *corsMiddleware) isMethodAllowed(method string) bool {
	for _, m := range m.config.AllowedMethods {
		if strings.EqualFold(m, method) {
			return true
		}
	}
	return false
}

func (m *corsMiddleware) checkHeaders(requested string) (bool, []string) {
	requestedHeaders := splitAndTrim(requested, ",")
	var rejected []string

	for _, h := range requestedHeaders {
		normalized := http.CanonicalHeaderKey(h)
		found := false
		for _, allowed := range m.config.AllowedHeaders {
			if allowed == "*" {
				found = true
				break
			}
			if http.CanonicalHeaderKey(allowed) == normalized {
				found = true
				break
			}
		}
		if !found {
			rejected = append(rejected, h)
		}
	}

	return len(rejected) == 0, rejected
}
