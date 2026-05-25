package quantum

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"google.golang.org/grpc"
)

type CircuitStatusType string

const (
	CircuitStatusPending    CircuitStatusType = "pending"
	CircuitStatusQueued     CircuitStatusType = "queued"
	CircuitStatusRunning    CircuitStatusType = "running"
	CircuitStatusCompleted  CircuitStatusType = "completed"
	CircuitStatusFailed     CircuitStatusType = "failed"
	CircuitStatusCancelled  CircuitStatusType = "cancelled"
)

type CircuitSubmission struct {
	ID              string            `json:"id,omitempty"`
	OwnerID         string            `json:"owner_id"`
	Name            string            `json:"name,omitempty"`
	Description     string            `json:"description,omitempty"`
	QubitCount      int               `json:"qubit_count"`
	Depth           int               `json:"depth"`
	Shots           int               `json:"shots"`
	CircuitCode     string            `json:"circuit_code,omitempty"`
	CircuitJSON     interface{}       `json:"circuit_json,omitempty"`
	Gates           []GateOperation   `json:"gates,omitempty"`
	Measurements    []Measurement     `json:"measurements,omitempty"`
	Backend         string            `json:"backend"`
	Optimization    int               `json:"optimization,omitempty"`
	ErrorMitigation bool              `json:"error_mitigation,omitempty"`
	Parameters      map[string]float64 `json:"parameters,omitempty"`
	Metadata        map[string]string `json:"metadata,omitempty"`
	CreatedAt       time.Time         `json:"created_at,omitempty"`
}

type GateOperation struct {
	Name       string    `json:"name"`
	Target     []int     `json:"target"`
	Control    []int     `json:"control,omitempty"`
	Parameter  float64   `json:"parameter,omitempty"`
	Parameters []float64 `json:"parameters,omitempty"`
}

type Measurement struct {
	Qubit    int `json:"qubit"`
	Classical int `json:"classical,omitempty"`
}

type CircuitStatus struct {
	ID          string            `json:"id"`
	OwnerID     string            `json:"owner_id"`
	Status      CircuitStatusType `json:"status"`
	QueuePosition int              `json:"queue_position,omitempty"`
	Progress    float64           `json:"progress,omitempty"`
	Backend     string            `json:"backend"`
	QubitCount  int               `json:"qubit_count"`
	Shots       int               `json:"shots"`
	EstimatedTimeLeft float64    `json:"estimated_time_left_seconds,omitempty"`
	Error       string            `json:"error,omitempty"`
	CreatedAt   time.Time         `json:"created_at"`
	UpdatedAt   time.Time         `json:"updated_at"`
	StartedAt   *time.Time        `json:"started_at,omitempty"`
	CompletedAt *time.Time        `json:"completed_at,omitempty"`
}

type CircuitResult struct {
	ID            string                 `json:"id"`
	Status        CircuitStatusType      `json:"status"`
	Counts        map[string]int         `json:"counts"`
	Probabilities map[string]float64     `json:"probabilities"`
	StateVector   []complex128           `json:"state_vector,omitempty"`
	DensityMatrix interface{}            `json:"density_matrix,omitempty"`
	ExpectationValues map[string]float64 `json:"expectation_values,omitempty"`
	ExecutionTime float64                `json:"execution_time_seconds"`
	NumberOfShots int                    `json:"number_of_shots"`
	Backend       string                 `json:"backend"`
	OptimizationLevel int                `json:"optimization_level"`
	ErrorMitigationApplied bool          `json:"error_mitigation_applied"`
	NoiseModel    string                 `json:"noise_model,omitempty"`
	Metrics       ExecutionMetrics       `json:"metrics"`
	CreatedAt     time.Time              `json:"created_at"`
	CompletedAt   time.Time              `json:"completed_at"`
}

type ExecutionMetrics struct {
	CNOTCount          int     `json:"cnot_count"`
	GateCount          int     `json:"gate_count"`
	Depth              int     `json:"depth"`
	Width              int     `json:"width"`
	MultiQubitGates    int     `json:"multi_qubit_gates"`
	MeasurementCount   int     `json:"measurement_count"`
	TranspilationTime  float64 `json:"transpilation_time_seconds"`
	ExecutionTime      float64 `json:"execution_time_seconds"`
	ClassicalBits      int     `json:"classical_bits"`
}

type CostEstimate struct {
	EstimatedCost      float64       `json:"estimated_cost"`
	Currency           string        `json:"currency"`
	Breakdown          CostBreakdown `json:"breakdown"`
	EstimatedDuration  time.Duration `json:"estimated_duration_seconds"`
	Priority           string        `json:"priority"`
}

type CostBreakdown struct {
	BaseCost       float64 `json:"base_cost"`
	QubitCost      float64 `json:"qubit_cost"`
	ShotsCost      float64 `json:"shots_cost"`
	DepthCost      float64 `json:"depth_cost"`
	PriorityCost   float64 `json:"priority_cost,omitempty"`
	Total          float64 `json:"total"`
}

type Client interface {
	Submit(ctx context.Context, circuit *CircuitSubmission) (*CircuitStatus, error)
	GetStatus(ctx context.Context, id string) (*CircuitStatus, error)
	GetResult(ctx context.Context, id string) (*CircuitResult, error)
	EstimateCost(ctx context.Context, circuit *CircuitSubmission) (*CostEstimate, error)
	List(ctx context.Context, ownerID string, limit, offset int) ([]*CircuitStatus, error)
	Cancel(ctx context.Context, id string) error
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
			Timeout: 30 * time.Second,
		},
		apiKey: apiKey,
	}
}

func (c *HTTPClient) Submit(ctx context.Context, circuit *CircuitSubmission) (*CircuitStatus, error) {
	url := c.baseURL + "/api/v1/quantum/circuits"

	body, err := json.Marshal(circuit)
	if err != nil {
		return nil, fmt.Errorf("marshaling circuit: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
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

	if resp.StatusCode != http.StatusAccepted && resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var status CircuitStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &status, nil
}

func (c *HTTPClient) GetStatus(ctx context.Context, id string) (*CircuitStatus, error) {
	url := c.baseURL + "/api/v1/quantum/circuits/" + id + "/status"

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
		return nil, fmt.Errorf("circuit not found: %s", id)
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var status CircuitStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &status, nil
}

func (c *HTTPClient) GetResult(ctx context.Context, id string) (*CircuitResult, error) {
	url := c.baseURL + "/api/v1/quantum/circuits/" + id

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
		return nil, fmt.Errorf("circuit not found: %s", id)
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	var result CircuitResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &result, nil
}

func (c *HTTPClient) EstimateCost(ctx context.Context, circuit *CircuitSubmission) (*CostEstimate, error) {
	url := c.baseURL + "/api/v1/quantum/estimate"

	body, err := json.Marshal(circuit)
	if err != nil {
		return nil, fmt.Errorf("marshaling circuit: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
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

	var estimate CostEstimate
	if err := json.NewDecoder(resp.Body).Decode(&estimate); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return &estimate, nil
}

func (c *HTTPClient) List(ctx context.Context, ownerID string, limit, offset int) ([]*CircuitStatus, error) {
	url := fmt.Sprintf("%s/api/v1/quantum/circuits?owner_id=%s&limit=%d&offset=%d", c.baseURL, ownerID, limit, offset)

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
		Circuits []*CircuitStatus `json:"circuits"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return response.Circuits, nil
}

func (c *HTTPClient) Cancel(ctx context.Context, id string) error {
	url := c.baseURL + "/api/v1/quantum/circuits/" + id + "/cancel"

	req, err := http.NewRequestWithContext(ctx, "POST", url, nil)
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}

	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	return nil
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

func (c *GRPCClient) Submit(ctx context.Context, circuit *CircuitSubmission) (*CircuitStatus, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) GetStatus(ctx context.Context, id string) (*CircuitStatus, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) GetResult(ctx context.Context, id string) (*CircuitResult, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) EstimateCost(ctx context.Context, circuit *CircuitSubmission) (*CostEstimate, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) List(ctx context.Context, ownerID string, limit, offset int) ([]*CircuitStatus, error) {
	return nil, fmt.Errorf("grpc client not fully implemented")
}

func (c *GRPCClient) Cancel(ctx context.Context, id string) error {
	return fmt.Errorf("grpc client not fully implemented")
}
