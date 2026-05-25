package api

import (
	"database/sql"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/middleware"
	"github.com/quantumworld-dpdns-io/dgsn/internal/scheduling"
)

type ScheduleHandler struct {
	service ScheduleService
	logger  *slog.Logger
}

func NewScheduleHandler(service ScheduleService, logger *slog.Logger) *ScheduleHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &ScheduleHandler{
		service: service,
		logger:  logger,
	}
}

func (h *ScheduleHandler) CreateSlot(w http.ResponseWriter, r *http.Request) {
	ownerID := middleware.GetOwnerIDFromContext(r.Context())
	if ownerID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no owner id found")
		return
	}

	var input scheduling.CreateSlotInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	slot, err := h.service.CreateSlot(r.Context(), input, ownerID)
	if err != nil {
		h.logger.Error("failed to create schedule slot", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to create schedule slot")
		return
	}

	h.logger.Info("schedule slot created",
		"slot_id", slot.ID,
		"station_id", slot.StationID,
		"start_time", slot.StartTime)
	JSONResponse(w, http.StatusCreated, slot)
}

func (h *ScheduleHandler) GetSlot(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "slot id required")
		return
	}

	slot, err := h.service.GetSlot(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "slot not found")
			return
		}
		h.logger.Error("failed to get slot", "error", err, "slot_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to get slot")
		return
	}

	JSONResponse(w, http.StatusOK, slot)
}

func (h *ScheduleHandler) GetSchedule(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	filter := scheduling.ScheduleFilter{}
	filter.StationID = query.Get("station_id")
	filter.OwnerID = query.Get("owner_id")

	if status := query.Get("status"); status != "" {
		s := scheduling.SlotStatus(status)
		filter.Status = &s
	}

	if fromTime := query.Get("from_time"); fromTime != "" {
		if t, err := time.Parse(time.RFC3339, fromTime); err == nil {
			filter.FromTime = &t
		}
	}

	if toTime := query.Get("to_time"); toTime != "" {
		if t, err := time.Parse(time.RFC3339, toTime); err == nil {
			filter.ToTime = &t
		}
	}

	limit, offset := GetPagination(r, 100, 1000)
	filter.Limit = limit
	filter.Offset = offset

	slots, err := h.service.ListSlots(r.Context(), filter)
	if err != nil {
		h.logger.Error("failed to list schedule slots", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to list schedule slots")
		return
	}

	response := map[string]interface{}{
		"slots": slots,
		"pagination": map[string]int{
			"limit":  limit,
			"offset": offset,
			"count":  len(slots),
		},
	}

	JSONResponse(w, http.StatusOK, response)
}

func (h *ScheduleHandler) AssignStation(w http.ResponseWriter, r *http.Request) {
	slotID := r.PathValue("id")
	if slotID == "" {
		JSONError(w, http.StatusBadRequest, "slot id required")
		return
	}

	userID := middleware.GetOwnerIDFromContext(r.Context())
	if userID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no user id found")
		return
	}

	assignment, err := h.service.AssignSlot(r.Context(), slotID, userID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "slot not found")
			return
		}
		if strings.Contains(err.Error(), "not available") {
			JSONError(w, http.StatusConflict, err.Error())
			return
		}
		if strings.Contains(err.Error(), "already has an assignment") {
			JSONError(w, http.StatusConflict, err.Error())
			return
		}
		h.logger.Error("failed to assign slot", "error", err, "slot_id", slotID)
		JSONError(w, http.StatusInternalServerError, "failed to assign slot")
		return
	}

	h.logger.Info("slot assigned",
		"slot_id", slotID,
		"user_id", userID,
		"assignment_id", assignment.ID)
	JSONResponse(w, http.StatusOK, assignment)
}

func (h *ScheduleHandler) ReleaseSlot(w http.ResponseWriter, r *http.Request) {
	slotID := r.PathValue("id")
	if slotID == "" {
		JSONError(w, http.StatusBadRequest, "slot id required")
		return
	}

	err := h.service.ReleaseSlot(r.Context(), slotID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "slot not found")
			return
		}
		h.logger.Error("failed to release slot", "error", err, "slot_id", slotID)
		JSONError(w, http.StatusInternalServerError, "failed to release slot")
		return
	}

	h.logger.Info("slot released", "slot_id", slotID)
	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"slot_id": slotID,
		"status":  "released",
	})
}

func (h *ScheduleHandler) ListConflicts(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	stationID := query.Get("station_id")
	if stationID == "" {
		JSONError(w, http.StatusBadRequest, "station_id required")
		return
	}

	var fromTime, toTime time.Time
	var err error

	if fromStr := query.Get("from_time"); fromStr != "" {
		fromTime, err = time.Parse(time.RFC3339, fromStr)
		if err != nil {
			JSONError(w, http.StatusBadRequest, "invalid from_time format")
			return
		}
	} else {
		fromTime = time.Now()
	}

	if toStr := query.Get("to_time"); toStr != "" {
		toTime, err = time.Parse(time.RFC3339, toStr)
		if err != nil {
			JSONError(w, http.StatusBadRequest, "invalid to_time format")
			return
		}
	} else {
		toTime = fromTime.Add(24 * time.Hour)
	}

	conflicts, err := h.service.FindConflicts(r.Context(), stationID, fromTime, toTime)
	if err != nil {
		h.logger.Error("failed to find conflicts", "error", err, "station_id", stationID)
		JSONError(w, http.StatusInternalServerError, "failed to find conflicts")
		return
	}

	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"station_id": stationID,
		"from_time":  fromTime,
		"to_time":    toTime,
		"conflicts":  conflicts,
		"count":      len(conflicts),
	})
}

func (h *ScheduleHandler) FindAvailable(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	var fromTime, toTime time.Time
	var err error

	if fromStr := query.Get("from_time"); fromStr != "" {
		fromTime, err = time.Parse(time.RFC3339, fromStr)
		if err != nil {
			JSONError(w, http.StatusBadRequest, "invalid from_time format")
			return
		}
	} else {
		fromTime = time.Now()
	}

	if toStr := query.Get("to_time"); toStr != "" {
		toTime, err = time.Parse(time.RFC3339, toStr)
		if err != nil {
			JSONError(w, http.StatusBadRequest, "invalid to_time format")
			return
		}
	} else {
		toTime = fromTime.Add(24 * time.Hour)
	}

	var capabilities []string
	if caps := query.Get("capabilities"); caps != "" {
		capabilities = strings.Split(caps, ",")
		for i, c := range capabilities {
			capabilities[i] = strings.TrimSpace(c)
		}
	}

	slots, err := h.service.FindAvailable(r.Context(), fromTime, toTime, capabilities)
	if err != nil {
		h.logger.Error("failed to find available slots", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to find available slots")
		return
	}

	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"from_time":    fromTime,
		"to_time":      toTime,
		"capabilities": capabilities,
		"slots":        slots,
		"count":        len(slots),
	})
}

func GetPagination(r *http.Request, defaultLimit, maxLimit int) (limit, offset int) {
	query := r.URL.Query()

	limit = defaultLimit
	if l := query.Get("limit"); l != "" {
		parsed, err := strconv.Atoi(l)
		if err == nil && parsed > 0 {
			limit = parsed
		}
	}
	if limit > maxLimit {
		limit = maxLimit
	}

	offset = 0
	if o := query.Get("offset"); o != "" {
		parsed, err := strconv.Atoi(o)
		if err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	return limit, offset
}
