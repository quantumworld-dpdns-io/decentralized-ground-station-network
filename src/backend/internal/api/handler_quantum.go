package api

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/quantumworld-dpdns-io/dgsn/internal/middleware"
	"github.com/quantumworld-dpdns-io/dgsn/pkg/quantum"
)

type QuantumHandler struct {
	service QuantumService
	logger  *slog.Logger
}

func NewQuantumHandler(service QuantumService, logger *slog.Logger) *QuantumHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &QuantumHandler{
		service: service,
		logger:  logger,
	}
}

func (h *QuantumHandler) SubmitCircuit(w http.ResponseWriter, r *http.Request) {
	ownerID := middleware.GetOwnerIDFromContext(r.Context())
	if ownerID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no owner id found")
		return
	}

	var input quantum.CircuitSubmission
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if input.OwnerID == "" {
		input.OwnerID = ownerID
	}

	status, err := h.service.SubmitCircuit(r.Context(), &input)
	if err != nil {
		h.logger.Error("failed to submit circuit", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to submit circuit")
		return
	}

	h.logger.Info("circuit submitted",
		"circuit_id", status.ID,
		"owner_id", ownerID,
		"status", status.Status)
	JSONResponse(w, http.StatusAccepted, status)
}

func (h *QuantumHandler) GetCircuitResult(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "circuit id required")
		return
	}

	result, err := h.service.GetCircuitResult(r.Context(), id)
	if err != nil {
		h.logger.Error("failed to get circuit result", "error", err, "circuit_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to get circuit result")
		return
	}

	if result == nil {
		status, err := h.service.GetCircuitStatus(r.Context(), id)
		if err != nil {
			JSONError(w, http.StatusNotFound, "circuit not found")
			return
		}
		JSONResponse(w, http.StatusOK, map[string]interface{}{
			"id":     status.ID,
			"status": status.Status,
			"reason": "result not yet available",
		})
		return
	}

	JSONResponse(w, http.StatusOK, result)
}

func (h *QuantumHandler) GetCircuitStatus(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "circuit id required")
		return
	}

	status, err := h.service.GetCircuitStatus(r.Context(), id)
	if err != nil {
		h.logger.Error("failed to get circuit status", "error", err, "circuit_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to get circuit status")
		return
	}

	if status == nil {
		JSONError(w, http.StatusNotFound, "circuit not found")
		return
	}

	JSONResponse(w, http.StatusOK, status)
}

func (h *QuantumHandler) ListCircuits(w http.ResponseWriter, r *http.Request) {
	ownerID := middleware.GetOwnerIDFromContext(r.Context())
	if ownerID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no owner id found")
		return
	}

	limit, offset := GetPagination(r, 100, 1000)

	circuits, err := h.service.ListCircuits(r.Context(), ownerID, limit, offset)
	if err != nil {
		h.logger.Error("failed to list circuits", "error", err, "owner_id", ownerID)
		JSONError(w, http.StatusInternalServerError, "failed to list circuits")
		return
	}

	response := map[string]interface{}{
		"circuits": circuits,
		"pagination": map[string]int{
			"limit":  limit,
			"offset": offset,
			"count":  len(circuits),
		},
	}

	JSONResponse(w, http.StatusOK, response)
}

func (h *QuantumHandler) EstimateCost(w http.ResponseWriter, r *http.Request) {
	ownerID := middleware.GetOwnerIDFromContext(r.Context())
	if ownerID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no owner id found")
		return
	}

	var input quantum.CircuitSubmission
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if input.OwnerID == "" {
		input.OwnerID = ownerID
	}

	cost, err := h.service.EstimateCost(r.Context(), &input)
	if err != nil {
		h.logger.Error("failed to estimate cost", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to estimate cost")
		return
	}

	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"estimated_cost": cost,
		"qubit_count":    input.QubitCount,
		"depth":          input.Depth,
		"shots":          input.Shots,
	})
}

func (h *QuantumHandler) Benchmark(w http.ResponseWriter, r *http.Request) {
	ownerID := middleware.GetOwnerIDFromContext(r.Context())
	if ownerID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no owner id found")
		return
	}

	var req struct {
		BenchmarkType string `json:"benchmark_type"`
		Qubits        int    `json:"qubits"`
		Depth         int    `json:"depth"`
		Shots         int    `json:"shots"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Qubits <= 0 {
		req.Qubits = 5
	}
	if req.Depth <= 0 {
		req.Depth = 10
	}
	if req.Shots <= 0 {
		req.Shots = 1024
	}
	if req.BenchmarkType == "" {
		req.BenchmarkType = "random"
	}

	circuit := &quantum.CircuitSubmission{
		OwnerID:        ownerID,
		QubitCount:     req.Qubits,
		Depth:          req.Depth,
		Shots:          req.Shots,
		Backend:        "simulator",
		Optimization:   1,
		ErrorMitigation: true,
	}

	status, err := h.service.SubmitCircuit(r.Context(), circuit)
	if err != nil {
		h.logger.Error("failed to submit benchmark circuit", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to submit benchmark")
		return
	}

	h.logger.Info("benchmark submitted",
		"benchmark_type", req.BenchmarkType,
		"circuit_id", status.ID,
		"qubits", req.Qubits,
		"depth", req.Depth)

	JSONResponse(w, http.StatusAccepted, map[string]interface{}{
		"benchmark_type": req.BenchmarkType,
		"circuit_id":     status.ID,
		"status":         status.Status,
		"parameters": map[string]int{
			"qubits": req.Qubits,
			"depth":  req.Depth,
			"shots":  req.Shots,
		},
	})
}
