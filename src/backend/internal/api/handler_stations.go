package api

import (
	"database/sql"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/quantumworld-dpdns-io/dgsn/internal/middleware"
	"github.com/quantumworld-dpdns-io/dgsn/internal/stations"
)

type StationHandler struct {
	service StationService
	logger  *slog.Logger
}

func NewStationHandler(service StationService, logger *slog.Logger) *StationHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &StationHandler{
		service: service,
		logger:  logger,
	}
}

func (h *StationHandler) Register(w http.ResponseWriter, r *http.Request) {
	ownerID := middleware.GetOwnerIDFromContext(r.Context())
	if ownerID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no owner id found")
		return
	}

	body := middleware.ValidatedBodyFromContext(r.Context())
	if body == nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	input, ok := body.(*stations.RegisterStationInput)
	if !ok {
		JSONError(w, http.StatusBadRequest, "invalid request body type")
		return
	}

	station, err := h.service.Register(r.Context(), *input, ownerID)
	if err != nil {
		h.logger.Error("failed to register station", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to register station")
		return
	}

	h.logger.Info("station registered", "station_id", station.ID, "owner_id", ownerID)
	JSONResponse(w, http.StatusCreated, station)
}

func (h *StationHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "station id required")
		return
	}

	station, err := h.service.Get(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "station not found")
			return
		}
		h.logger.Error("failed to get station", "error", err, "station_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to get station")
		return
	}

	JSONResponse(w, http.StatusOK, station)
}

func (h *StationHandler) List(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	filter := stations.StationFilter{}

	if status := query.Get("status"); status != "" {
		s := stations.StationStatus(status)
		filter.Status = &s
	}

	if capability := query.Get("capability"); capability != "" {
		c := stations.CapabilityType(capability)
		filter.Capability = &c
	}

	if verifiedStr := query.Get("verified"); verifiedStr != "" {
		var verified bool
		if verifiedStr == "true" {
			verified = true
			filter.Verified = &verified
		} else if verifiedStr == "false" {
			verified = false
			filter.Verified = &verified
		}
	}

	filter.OwnerID = query.Get("owner_id")

	limit, offset := GetPagination(r, 100, 1000)
	filter.Limit = limit
	filter.Offset = offset

	stationsList, err := h.service.List(r.Context(), filter)
	if err != nil {
		h.logger.Error("failed to list stations", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to list stations")
		return
	}

	response := map[string]interface{}{
		"stations": stationsList,
		"pagination": map[string]int{
			"limit":  limit,
			"offset": offset,
			"count":  len(stationsList),
		},
	}

	JSONResponse(w, http.StatusOK, response)
}

func (h *StationHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "station id required")
		return
	}

	body := middleware.ValidatedBodyFromContext(r.Context())
	if body == nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	input, ok := body.(*stations.UpdateStationInput)
	if !ok {
		JSONError(w, http.StatusBadRequest, "invalid request body type")
		return
	}

	station, err := h.service.Update(r.Context(), id, *input)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "station not found")
			return
		}
		h.logger.Error("failed to update station", "error", err, "station_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to update station")
		return
	}

	h.logger.Info("station updated", "station_id", id)
	JSONResponse(w, http.StatusOK, station)
}

func (h *StationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "station id required")
		return
	}

	err := h.service.Delete(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "station not found")
			return
		}
		h.logger.Error("failed to delete station", "error", err, "station_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to delete station")
		return
	}

	h.logger.Info("station deleted", "station_id", id)
	w.WriteHeader(http.StatusNoContent)
}

func (h *StationHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "station id required")
		return
	}

	var req struct {
		Status stations.StationStatus `json:"status"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Status == "" {
		JSONError(w, http.StatusBadRequest, "status is required")
		return
	}

	err := h.service.UpdateStatus(r.Context(), id, req.Status)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "station not found")
			return
		}
		h.logger.Error("failed to update station status", "error", err, "station_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to update station status")
		return
	}

	h.logger.Info("station status updated", "station_id", id, "status", req.Status)
	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"id":     id,
		"status": req.Status,
	})
}
