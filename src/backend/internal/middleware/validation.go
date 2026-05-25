package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"reflect"
	"strings"

	"github.com/go-playground/validator/v10"
)

var validate *validator.Validate

func init() {
	validate = validator.New()
}

var (
	ErrValidationFailed = errors.New("validation failed")
	ErrInvalidBody      = errors.New("invalid request body")
)

type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
	Value   interface{} `json:"value,omitempty"`
}

type ValidationErrorResponse struct {
	Error   string            `json:"error"`
	Errors  []ValidationError `json:"errors,omitempty"`
	Details string            `json:"details,omitempty"`
}

type validationMiddleware struct {
	validate *validator.Validate
}

func NewValidationMiddleware() *validationMiddleware {
	return &validationMiddleware{validate: validate}
}

func NewValidationMiddlewareWithCustom(v *validator.Validate) *validationMiddleware {
	if v == nil {
		v = validate
	}
	return &validationMiddleware{validate: v}
}

func (m *validationMiddleware) ValidateBody(dst interface{}) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			dstType := reflect.TypeOf(dst)
			if dstType.Kind() == reflect.Ptr {
				dstType = dstType.Elem()
			}
			target := reflect.New(dstType).Interface()

			bodyBytes, err := io.ReadAll(r.Body)
			if err != nil {
				m.writeValidationError(w, ErrInvalidBody, "failed to read request body")
				return
			}
			defer r.Body.Close()

			if len(bodyBytes) == 0 {
				m.writeValidationError(w, ErrInvalidBody, "request body is empty")
				return
			}

			if err := json.Unmarshal(bodyBytes, target); err != nil {
				var syntaxErr *json.SyntaxError
				var unmarshalErr *json.UnmarshalTypeError

				switch {
				case errors.As(err, &syntaxErr):
					msg := fmt.Sprintf("syntax error at position %d", syntaxErr.Offset)
					m.writeValidationError(w, err, msg)
				case errors.As(err, &unmarshalErr):
					msg := fmt.Sprintf("invalid type for field '%s': expected %s, got %s",
						unmarshalErr.Field, unmarshalErr.Type, unmarshalErr.Value)
					m.writeValidationError(w, err, msg)
				default:
					m.writeValidationError(w, err, "invalid json")
				}
				return
			}

			if err := m.validate.Struct(target); err != nil {
				var validationErrors validator.ValidationErrors
				if errors.As(err, &validationErrors) {
					errs := make([]ValidationError, 0, len(validationErrors))
					for _, e := range validationErrors {
						fieldName := e.Field()
						if jsonField, ok := getJSONFieldName(target, e.StructNamespace()); ok {
							fieldName = jsonField
						}
						errs = append(errs, ValidationError{
							Field:   fieldName,
							Message: m.tagToMessage(e),
							Value:   e.Value(),
						})
					}
					m.writeValidationErrors(w, errs)
					return
				}
				m.writeValidationError(w, err, "validation failed")
				return
			}

			r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

			ctx := context.WithValue(r.Context(), validatedBodyKey, target)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

type validatedBodyCtxKey struct{}

var validatedBodyKey = validatedBodyCtxKey{}

func ValidatedBodyFromContext(ctx context.Context) interface{} {
	return ctx.Value(validatedBodyKey)
}

func (m *validationMiddleware) tagToMessage(fe validator.FieldError) string {
	switch fe.Tag() {
	case "required":
		return "field is required"
	case "email":
		return "invalid email format"
	case "min":
		return fmt.Sprintf("minimum value is %s", fe.Param())
	case "max":
		return fmt.Sprintf("maximum value is %s", fe.Param())
	case "len":
		return fmt.Sprintf("length must be %s", fe.Param())
	case "gte":
		return fmt.Sprintf("must be greater than or equal to %s", fe.Param())
	case "lte":
		return fmt.Sprintf("must be less than or equal to %s", fe.Param())
	case "gt":
		return fmt.Sprintf("must be greater than %s", fe.Param())
	case "lt":
		return fmt.Sprintf("must be less than %s", fe.Param())
	case "uuid":
		return "invalid uuid format"
	case "url":
		return "invalid url format"
	case "alpha":
		return "must contain only letters"
	case "alphanum":
		return "must contain only letters and numbers"
	case "numeric":
		return "must be a valid number"
	case "oneof":
		return fmt.Sprintf("must be one of: %s", strings.ReplaceAll(fe.Param(), " ", ", "))
	default:
		return fmt.Sprintf("validation failed on tag '%s'", fe.Tag())
	}
}

func getJSONFieldName(target interface{}, namespace string) (string, bool) {
	parts := strings.Split(namespace, ".")
	if len(parts) < 2 {
		return "", false
	}

	targetType := reflect.TypeOf(target)
	if targetType.Kind() == reflect.Ptr {
		targetType = targetType.Elem()
	}

	for i := 1; i < len(parts); i++ {
		fieldName := parts[i]
		field, found := targetType.FieldByName(fieldName)
		if !found {
			return "", false
		}

		jsonTag := field.Tag.Get("json")
		if jsonTag != "" && jsonTag != "-" {
			tagParts := strings.Split(jsonTag, ",")
			if len(tagParts) > 0 && tagParts[0] != "" {
				if i == len(parts)-1 {
					return tagParts[0], true
				}
				if field.Type.Kind() == reflect.Ptr {
					targetType = field.Type.Elem()
				} else {
					targetType = field.Type
				}
			}
		} else {
			if i == len(parts)-1 {
				return fieldName, true
			}
			if field.Type.Kind() == reflect.Ptr {
				targetType = field.Type.Elem()
			} else {
				targetType = field.Type
			}
		}
	}

	return "", false
}

func (m *validationMiddleware) writeValidationError(w http.ResponseWriter, err error, details string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)

	resp := ValidationErrorResponse{
		Error:   "validation failed",
		Details: details,
	}
	json.NewEncoder(w).Encode(resp)
}

func (m *validationMiddleware) writeValidationErrors(w http.ResponseWriter, errs []ValidationError) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)

	resp := ValidationErrorResponse{
		Error:  "validation failed",
		Errors: errs,
	}
	json.NewEncoder(w).Encode(resp)
}
