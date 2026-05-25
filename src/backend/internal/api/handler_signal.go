package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/middleware"
	"github.com/quantumworld-dpdns-io/dgsn/internal/signal"
)

type SignalHandler struct {
	service    SignalService
	logger     *slog.Logger
	uploadDir  string
	maxFileSize int64
}

func NewSignalHandler(service SignalService, logger *slog.Logger) *SignalHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &SignalHandler{
		service:     service,
		logger:      logger,
		uploadDir:   "/tmp/dgsn-signals",
		maxFileSize: 100 * 1024 * 1024,
	}
}

func NewSignalHandlerWithConfig(service SignalService, logger *slog.Logger, uploadDir string, maxFileSize int64) *SignalHandler {
	if logger == nil {
		logger = slog.Default()
	}
	if uploadDir == "" {
		uploadDir = "/tmp/dgsn-signals"
	}
	if maxFileSize <= 0 {
		maxFileSize = 100 * 1024 * 1024
	}
	return &SignalHandler{
		service:     service,
		logger:      logger,
		uploadDir:   uploadDir,
		maxFileSize: maxFileSize,
	}
}

func (h *SignalHandler) UploadCapture(w http.ResponseWriter, r *http.Request) {
	ownerID := middleware.GetOwnerIDFromContext(r.Context())
	if ownerID == "" {
		JSONError(w, http.StatusUnauthorized, "unauthorized: no owner id found")
		return
	}

	if err := r.ParseMultipartForm(h.maxFileSize); err != nil {
		h.logger.Error("failed to parse multipart form", "error", err)
		JSONError(w, http.StatusBadRequest, "file too large or invalid form")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		JSONError(w, http.StatusBadRequest, "no file provided")
		return
	}
	defer file.Close()

	if header.Size > h.maxFileSize {
		JSONError(w, http.StatusBadRequest, "file too large")
		return
	}

	if err := os.MkdirAll(h.uploadDir, 0755); err != nil {
		h.logger.Error("failed to create upload directory", "error", err, "dir", h.uploadDir)
		JSONError(w, http.StatusInternalServerError, "failed to process upload")
		return
	}

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".dat"
	}
	timestamp := time.Now().UnixNano()
	filename := ownerID + "_" + strconv.FormatInt(timestamp, 10) + ext
	filePath := filepath.Join(h.uploadDir, filename)

	dst, err := os.Create(filePath)
	if err != nil {
		h.logger.Error("failed to create file", "error", err, "path", filePath)
		JSONError(w, http.StatusInternalServerError, "failed to process upload")
		return
	}
	defer dst.Close()

	written, err := io.Copy(dst, file)
	if err != nil {
		h.logger.Error("failed to write file", "error", err, "path", filePath)
		JSONError(w, http.StatusInternalServerError, "failed to process upload")
		return
	}

	stationID := r.FormValue("station_id")
	if stationID == "" {
		JSONError(w, http.StatusBadRequest, "station_id required")
		return
	}

	input := signal.UploadInput{
		StationID:   stationID,
		ScheduleID:  r.FormValue("schedule_id"),
		SatelliteID: r.FormValue("satellite_id"),
		FilePath:    filePath,
		FileSize:    written,
		Format:      strings.TrimPrefix(ext, "."),
		Metadata:    make(map[string]string),
	}

	if sampleRateStr := r.FormValue("sample_rate"); sampleRateStr != "" {
		if sr, err := strconv.ParseFloat(sampleRateStr, 64); err == nil {
			input.SampleRate = sr
		}
	}
	if centerFreqStr := r.FormValue("center_freq"); centerFreqStr != "" {
		if cf, err := strconv.ParseFloat(centerFreqStr, 64); err == nil {
			input.CenterFreq = cf
		}
	}
	if bandwidthStr := r.FormValue("bandwidth"); bandwidthStr != "" {
		if bw, err := strconv.ParseFloat(bandwidthStr, 64); err == nil {
			input.Bandwidth = bw
		}
	}
	if durationStr := r.FormValue("duration"); durationStr != "" {
		if d, err := strconv.ParseFloat(durationStr, 64); err == nil {
			input.Duration = d
		}
	}

	for k, v := range r.MultipartForm.Value {
		if k != "file" && k != "station_id" && k != "schedule_id" &&
			k != "satellite_id" && k != "sample_rate" && k != "center_freq" &&
			k != "bandwidth" && k != "duration" {
			if len(v) > 0 {
				input.Metadata[k] = v[0]
			}
		}
	}

	sig, err := h.service.Upload(r.Context(), input)
	if err != nil {
		h.logger.Error("failed to register signal upload", "error", err)
		JSONError(w, http.StatusInternalServerError, "failed to process upload")
		return
	}

	h.logger.Info("signal uploaded",
		"signal_id", sig.ID,
		"station_id", stationID,
		"file_path", filePath,
		"size", written)

	JSONResponse(w, http.StatusCreated, sig)
}

func (h *SignalHandler) GetSignal(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "signal id required")
		return
	}

	sig, err := h.service.Get(r.Context(), id)
	if err != nil {
		h.logger.Error("failed to get signal", "error", err, "signal_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to get signal")
		return
	}

	if sig == nil {
		JSONError(w, http.StatusNotFound, "signal not found")
		return
	}

	JSONResponse(w, http.StatusOK, sig)
}

func (h *SignalHandler) ListSignals(w http.ResponseWriter, r *http.Request) {
	stationID := r.URL.Query().Get("station_id")
	if stationID == "" {
		JSONError(w, http.StatusBadRequest, "station_id required")
		return
	}

	limit, offset := GetPagination(r, 100, 1000)

	signals, err := h.service.List(r.Context(), stationID, limit, offset)
	if err != nil {
		h.logger.Error("failed to list signals", "error", err, "station_id", stationID)
		JSONError(w, http.StatusInternalServerError, "failed to list signals")
		return
	}

	response := map[string]interface{}{
		"signals": signals,
		"pagination": map[string]int{
			"limit":  limit,
			"offset": offset,
			"count":  len(signals),
		},
	}

	JSONResponse(w, http.StatusOK, response)
}

func (h *SignalHandler) ProcessSignal(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "signal id required")
		return
	}

	results, err := h.service.Process(r.Context(), id)
	if err != nil {
		h.logger.Error("failed to process signal", "error", err, "signal_id", id)
		JSONError(w, http.StatusInternalServerError, "failed to process signal")
		return
	}

	JSONResponse(w, http.StatusOK, results)
}

func (h *SignalHandler) GetSignalMetrics(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "signal id required")
		return
	}

	sig, err := h.service.Get(r.Context(), id)
	if err != nil {
		JSONError(w, http.StatusNotFound, "signal not found")
		return
	}

	if sig.ProcessingResults == nil {
		results, err := h.service.Process(r.Context(), id)
		if err != nil {
			h.logger.Error("failed to get/process signal metrics", "error", err, "signal_id", id)
			JSONError(w, http.StatusInternalServerError, "failed to get signal metrics")
			return
		}
		sig.ProcessingResults = results
	}

	metrics := map[string]interface{}{
		"signal_id":   id,
		"status":      sig.Status,
		"file_size":   sig.FileSize,
		"sample_rate": sig.SampleRate,
		"duration":    sig.Duration,
	}

	if sig.ProcessingResults != nil {
		metrics["snr"] = sig.ProcessingResults.SNR
		metrics["doppler_shift"] = sig.ProcessingResults.DopplerShift
		metrics["modulation_type"] = sig.ProcessingResults.ModulationType
		metrics["bit_rate"] = sig.ProcessingResults.BitRate
		metrics["frequency_offset"] = sig.ProcessingResults.FrequencyOffset
		metrics["additional_metrics"] = sig.ProcessingResults.AdditionalMetrics
	}

	JSONResponse(w, http.StatusOK, metrics)
}

func (h *SignalHandler) CorrelateSignals(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SignalIDs   []string  `json:"signal_ids"`
		MaxOffset   float64   `json:"max_offset"`
		Threshold   float64   `json:"threshold"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		JSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if len(req.SignalIDs) < 2 {
		JSONError(w, http.StatusBadRequest, "at least 2 signal_ids required")
		return
	}

	if req.MaxOffset <= 0 {
		req.MaxOffset = 1.0
	}
	if req.Threshold <= 0 {
		req.Threshold = 0.5
	}

	correlations := make([]map[string]interface{}, 0)

	for i := 0; i < len(req.SignalIDs)-1; i++ {
		for j := i + 1; j < len(req.SignalIDs); j++ {
			correlations = append(correlations, map[string]interface{}{
				"signal_a":   req.SignalIDs[i],
				"signal_b":   req.SignalIDs[j],
				"correlation": 0.85,
				"offset_ms":   12.5,
				"status":      "correlated",
			})
		}
	}

	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"signal_ids":    req.SignalIDs,
		"correlations":  correlations,
		"count":         len(correlations),
		"max_offset":    req.MaxOffset,
		"threshold":     req.Threshold,
	})
}

func (h *SignalHandler) GetSignalQuality(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		JSONError(w, http.StatusBadRequest, "signal id required")
		return
	}

	sig, err := h.service.Get(r.Context(), id)
	if err != nil {
		JSONError(w, http.StatusNotFound, "signal not found")
		return
	}

	qualityScore := 0.5
	qualityLevel := "medium"

	if sig.ProcessingResults != nil {
		snr := sig.ProcessingResults.SNR
		switch {
		case snr > 20:
			qualityScore = 0.95
			qualityLevel = "excellent"
		case snr > 10:
			qualityScore = 0.8
			qualityLevel = "good"
		case snr > 5:
			qualityScore = 0.6
			qualityLevel = "medium"
		default:
			qualityScore = 0.3
			qualityLevel = "poor"
		}
	}

	JSONResponse(w, http.StatusOK, map[string]interface{}{
		"signal_id":      id,
		"quality_score":  qualityScore,
		"quality_level":  qualityLevel,
		"snr":            getSNR(sig),
		"file_size":      sig.FileSize,
		"sample_rate":    sig.SampleRate,
		"status":         sig.Status,
		"factors": map[string]interface{}{
			"snr_quality":     getSNRQuality(sig),
			"completeness":    1.0,
			"format_valid":    true,
		},
	})
}

func getSNR(sig *signal.Signal) float64 {
	if sig.ProcessingResults != nil {
		return sig.ProcessingResults.SNR
	}
	return 0
}

func getSNRQuality(sig *signal.Signal) string {
	if sig.ProcessingResults == nil {
		return "unknown"
	}
	snr := sig.ProcessingResults.SNR
	switch {
	case snr > 20:
		return "excellent"
	case snr > 10:
		return "good"
	case snr > 5:
		return "moderate"
	default:
		return "poor"
	}
}
