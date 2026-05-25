package signal

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"google.golang.org/grpc"
)

type ProcessResult struct {
	SignalID            string             `json:"signal_id"`
	SNR                 float64            `json:"snr"`
	DopplerShift        float64            `json:"doppler_shift"`
	ModulationType      string             `json:"modulation_type,omitempty"`
	BitRate             float64            `json:"bit_rate,omitempty"`
	FrequencyOffset     float64            `json:"frequency_offset,omitempty"`
	DecodedData         string             `json:"decoded_data,omitempty"`
	SpectrogramPath     string             `json:"spectrogram_path,omitempty"`
	ConstellationPath   string             `json:"constellation_path,omitempty"`
	AdditionalMetrics   map[string]float64 `json:"additional_metrics,omitempty"`
	ProcessingTime      float64            `json:"processing_time_seconds"`
}

type UploadResponse struct {
	SignalID  string `json:"signal_id"`
	StationID string `json:"station_id"`
	FileName  string `json:"file_name"`
	FileSize  int64  `json:"file_size"`
	Status    string `json:"status"`
}

type SignalInfo struct {
	ID          string            `json:"id"`
	StationID   string            `json:"station_id"`
	ScheduleID  string            `json:"schedule_id,omitempty"`
	SatelliteID string            `json:"satellite_id,omitempty"`
	Status      string            `json:"status"`
	FilePath    string            `json:"file_path"`
	FileSize    int64             `json:"file_size"`
	SampleRate  float64           `json:"sample_rate"`
	CenterFreq  float64           `json:"center_freq"`
	Bandwidth   float64           `json:"bandwidth"`
	Duration    float64           `json:"duration"`
	Format      string            `json:"format"`
	Metadata    map[string]string `json:"metadata,omitempty"`
	CreatedAt   time.Time         `json:"created_at"`
}

type CorrelationRequest struct {
	SignalIDs   []string `json:"signal_ids"`
	MaxOffset   float64  `json:"max_offset_seconds"`
	Threshold   float64  `json:"threshold"`
}

type CorrelationResult struct {
	SignalA     string  `json:"signal_a"`
	SignalB     string  `json:"signal_b"`
	Correlation float64 `json:"correlation"`
	OffsetMs    float64 `json:"offset_ms"`
	Status      string  `json:"status"`
}

type QualityMetrics struct {
	SignalID      string  `json:"signal_id"`
	QualityScore  float64 `json:"quality_score"`
	QualityLevel  string  `json:"quality_level"`
	SNR           float64 `json:"snr"`
	FileSize      int64   `json:"file_size"`
	SampleRate    float64 `json:"sample_rate"`
	Status        string  `json:"status"`
	Factors       struct {
		SNRQuality    string  `json:"snr_quality"`
		Completeness  float64 `json:"completeness"`
		FormatValid   bool    `json:"format_valid"`
	} `json:"factors"`
}

type Client interface {
	Process(ctx context.Context, signalID string) (*ProcessResult, error)
	Upload(ctx context.Context, stationID string, filePath string, metadata map[string]string) (*UploadResponse, error)
	GetInfo(ctx context.Context, signalID string) (*SignalInfo, error)
	Correlate(ctx context.Context, req *CorrelationRequest) ([]*CorrelationResult, error)
	GetQuality(ctx context.Context, signalID string) (*QualityMetrics, error)
	List(ctx context.Context, stationID string, limit, offset int) ([]*SignalInfo, error)
}

type HTTPClient struct {
	baseURL    string
	httpClient *http.Client
	apiKey     string
}

func NewHTTPClient(baseURL, apiKey string) *HTTPClient {
	return &HTTPClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
		apiKey: apiKey,
	}
}

func (c *HTTPClient) Process(ctx context.Context, signalID string) (*ProcessResult, error) {
	url := c.baseURL + "/api/v1/signals/" + signalID + "/process"

	req, err := http.NewRequestWithContext(ctx, "POST", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var result ProcessResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &result, nil
}

func (c *HTTPClient) Upload(ctx context.Context, stationID string, filePath string, metadata map[string]string) (*UploadResponse, error) {
	url := c.baseURL + "/api/v1/signals/upload"

	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("opening file: %w", err)
	}
	defer file.Close()

	fileInfo, err := file.Stat()
	if err != nil {
		return nil, fmt.Errorf("getting file info: %w", err)
	}

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	_ = writer.WriteField("station_id", stationID)
	_ = writer.WriteField("file_name", filepath.Base(filePath))
	_ = writer.WriteField("file_size", fmt.Sprintf("%d", fileInfo.Size()))

	for k, v := range metadata {
		_ = writer.WriteField(k, v)
	}

	part, err := writer.CreateFormFile("file", filepath.Base(filePath))
	if err != nil {
		return nil, fmt.Errorf("creating form file: %w", err)
	}

	_, err = io.Copy(part, file)
	if err != nil {
		return nil, fmt.Errorf("copying file: %w", err)
	}

	writer.Close()

	req, err := http.NewRequestWithContext(ctx, "POST", url, body)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", writer.FormDataContentType())
	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var result UploadResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &result, nil
}

func (c *HTTPClient) GetInfo(ctx context.Context, signalID string) (*SignalInfo, error) {
	url := c.baseURL + "/api/v1/signals/" + signalID

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, fmt.Errorf("signal not found: %s", signalID)
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var info SignalInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &info, nil
}

func (c *HTTPClient) Correlate(ctx context.Context, req *CorrelationRequest) ([]*CorrelationResult, error) {
	url := c.baseURL + "/api/v1/signals/correlate"

	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshaling request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		httpReq.Header.Set("X-API-Key", c.apiKey)
	}

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var response struct {
		Correlations []*CorrelationResult `json:"correlations"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return response.Correlations, nil
}

func (c *HTTPClient) GetQuality(ctx context.Context, signalID string) (*QualityMetrics, error) {
	url := c.baseURL + "/api/v1/signals/" + signalID + "/quality"

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, fmt.Errorf("signal not found: %s", signalID)
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var metrics QualityMetrics
	if err := json.NewDecoder(resp.Body).Decode(&metrics); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &metrics, nil
}

func (c *HTTPClient) List(ctx context.Context, stationID string, limit, offset int) ([]*SignalInfo, error) {
	url := fmt.Sprintf("%s/api/v1/signals?station_id=%s&limit=%d&offset=%d", c.baseURL, stationID, limit, offset)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var response struct {
		Signals []*SignalInfo `json:"signals"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return response.Signals, nil
}

type GRPCClient struct {
	conn   *grpc.ClientConn
	apiKey string
}

func NewGRPCClient(conn *grpc.ClientConn, apiKey string) *GRPCClient {
	return &GRPCClient{
		conn:   conn,
		apiKey: apiKey,
	}
}

func (c *GRPCClient) Process(ctx context.Context, signalID string) (*ProcessResult, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) Upload(ctx context.Context, stationID string, filePath string, metadata map[string]string) (*UploadResponse, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) GetInfo(ctx context.Context, signalID string) (*SignalInfo, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) Correlate(ctx context.Context, req *CorrelationRequest) ([]*CorrelationResult, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) GetQuality(ctx context.Context, signalID string) (*QualityMetrics, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) List(ctx context.Context, stationID string, limit, offset int) ([]*SignalInfo, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}
