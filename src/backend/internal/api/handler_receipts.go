package api

import (
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/middleware"
	"github.com/quantumworld-dpdns-io/dgsn/internal/receipts"
)

type ReceiptHandler struct {
	service ReceiptService
	logger  *slog.Logger
}

func NewReceiptHandler(service ReceiptService, logger *slog.Logger) *ReceiptHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &ReceiptHandler{
		service: service,
		logger:  logger,
	}
}

func (h *ReceiptHandler) Create(w http.ResponseWriter, r *http.Request) {
	body := middleware.ValidatedBodyFromContext(r.Context())
	if body == nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	input, ok := body.(*receipts.CreateReceiptInput)
	if !ok {
		JSONError(w, http.StatusBadRequest, "invalid request body type")
		return
	}

	receipt, err := h.service.Create(r.Context(), *input)
	if err != nil {
		if errors.Is(err, receipts.ErrDuplicateEntry) {
			JSONError(w, http.StatusConflict, "receipt already exists for this station and schedule")
			return
		}
		h.logger.Error("failed to create receipt", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to create receipt")
		return
	}

	h.logger.Info("receipt created", "receipt_id", receipt.ID, "station_id", receipt.StationID)
	JSONResponse(w, http.StatusCreated, receipt)
}

func (h *ReceiptHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "receipt id required")
		return
	}

	receipt, err := h.service.Get(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			JSONError(w, http.StatusNotFound, "receipt not found")
			return
		}
		h.logger.Error("failed to get receipt", "error", err, "receipt_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to get receipt")
		return
	}

	JSONResponse(w, http.StatusOK, receipt)
}

func (h *ReceiptHandler) List(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	filter := receipts.ReceiptFilter{}

	filter.StationID = query.Get("station_id")

	if status := query.Get("status"); status != "" {
		s := receipts.ReceiptStatus(status)
		filter.Status = &s
	}

	if fromDate := query.Get("from_date"); fromDate != "" {
		if t, err := time.Parse(time.RFC3339, fromDate); err == nil {
			filter.FromDate = &t
		}
	}

	if toDate := query.Get("to_date"); toDate != "" {
		if t, err := time.Parse(time.RFC3339, toDate); err == nil {
			filter.ToDate = &t
		}
	}

	limit, offset := GetPagination(r, 100, 1000)
	filter.Limit = limit
	filter.Offset = offset

	receiptsList, err := h.service.List(r.Context(), filter)
	if err != nil {
		h.logger.Error("failed to list receipts", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to list receipts")
		return
	}

	response := map[string]interface{}{
		"receipts": receiptsList,
		"pagination": map[string]int{
			"limit":  limit,
			"offset": offset,
			"count":  len(receiptsList),
		},
	}

	JSONResponse(w, http.StatusOK, response)
}

func (h *ReceiptHandler) Verify(w http.ResponseWriter, r *http.Request) {
	body := middleware.ValidatedBodyFromContext(r.Context())
	if body == nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	input, ok := body.(*receipts.VerifyReceiptInput)
	if !ok {
		JSONError(w, http.StatusBadRequest, "invalid request body type")
		return
	}

	result, err := h.service.Verify(r.Context(), *input)
	if err != nil {
		if errors.Is(err, receipts.ErrReceiptNotFound) {
			JSONError(w, http.StatusNotFound, "receipt not found")
			return
		}
		if errors.Is(err, receipts.ErrInvalidProof) {
			JSONErrorWithDetails(w, http.StatusBadRequest, "invalid proof", map[string]interface{}{
				"is_valid": false,
				"error":    err.Error(),
			})
			return
		}
		h.logger.Error("failed to verify receipt", "error", err, "receipt_id", input.ReceiptID)
		JSONError(w, http.StatusInternalServerError, "failed to verify receipt")
		return
	}

	h.logger.Info("receipt verification completed",
		"receipt_id", input.ReceiptID,
		"is_valid", result.IsValid)

	JSONResponse(w, http.StatusOK, result)
}

func (h *ReceiptHandler) Export(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	filter := receipts.ReceiptFilter{}
	filter.StationID = query.Get("station_id")

	if status := query.Get("status"); status != "" {
		s := receipts.ReceiptStatus(status)
		filter.Status = &s
	}

	if fromDate := query.Get("from_date"); fromDate != "" {
		if t, err := time.Parse(time.RFC3339, fromDate); err == nil {
			filter.FromDate = &t
		}
	}

	if toDate := query.Get("to_date"); toDate != "" {
		if t, err := time.Parse(time.RFC3339, toDate); err == nil {
			filter.ToDate = &t
		}
	}

	filter.Limit = 10000

	receiptsList, err := h.service.List(r.Context(), filter)
	if err != nil {
		h.logger.Error("failed to list receipts for export", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to export receipts")
		return
	}

	format := strings.ToLower(query.Get("format"))
	if format == "" {
		format = "json"
	}

	switch format {
	case "csv":
		h.exportCSV(w, receiptsList)
	case "jsonl":
		h.exportJSONL(w, receiptsList)
	default:
		JSONResponse(w, http.StatusOK, receiptsList)
	}
}

func (h *ReceiptHandler) exportCSV(w http.ResponseWriter, receiptsList []*receipts.Receipt) {
	w.Header().Set("Content-Type", "text/csv")
	w.Header().Set("Content-Disposition", "attachment; filename=receipts.csv")

	writer := csv.NewWriter(w)
	defer writer.Flush()

	headers := []string{
		"id", "station_id", "schedule_id", "task_id", "signal_id",
		"status", "proof_type", "proof_value", "chain_position",
		"created_at", "verified_at",
	}
	writer.Write(headers)

	for _, r := range receiptsList {
		verifiedAt := ""
		if r.VerifiedAt != nil {
			verifiedAt = r.VerifiedAt.Format(time.RFC3339)
		}

		row := []string{
			r.ID,
			r.StationID,
			r.ScheduleID,
			r.TaskID,
			r.SignalID,
			string(r.Status),
			string(r.Proof.Type),
			r.Proof.Value,
			strconv.FormatInt(r.ChainPosition, 10),
			r.CreatedAt.Format(time.RFC3339),
			verifiedAt,
		}
		writer.Write(row)
	}
}

func (h *ReceiptHandler) exportJSONL(w http.ResponseWriter, receiptsList []*receipts.Receipt) {
	w.Header().Set("Content-Type", "application/jsonl")
	w.Header().Set("Content-Disposition", "attachment; filename=receipts.jsonl")

	for _, r := range receiptsList {
		data, err := json.Marshal(r)
		if err != nil {
			h.logger.Warn("failed to marshal receipt for jsonl", "error", err)
			continue
		}
		w.Write(data)
		w.Write([]byte("\n"))
	}
}

func (h *ReceiptHandler) GetChain(w http.ResponseWriter, r *http.Request) {
	stationID := r.URL.Query().Get("station_id")
	if stationID == "" {
		JSONError(w, http.StatusBadRequest, "station_id required")
		return
	}

	filter := receipts.ReceiptFilter{
		StationID: stationID,
		Limit:     100,
	}

	chain, err := h.service.List(r.Context(), filter)
	if err != nil {
		h.logger.Error("failed to get receipt chain", "error", err, "station_id", stationID)
		JSONError(w, http.StatusInternalServerError, "failed to get receipt chain")
		return
	}

	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"station_id": stationID,
		"chain":      chain,
		"length":     len(chain),
	})
}
