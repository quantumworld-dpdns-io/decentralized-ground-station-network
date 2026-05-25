package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"github.com/quantumworld-dpdns-io/dgsn/pkg/quantum"
)

func (c *CLI) newQuantumCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "quantum",
		Short: "Manage quantum computing operations",
		Long:  "Submit quantum circuits, get results, and manage quantum operations",
	}

	cmd.AddCommand(c.newQuantumCircuitCmd())
	cmd.AddCommand(c.newQuantumListCmd())
	cmd.AddCommand(c.newQuantumEstimateCmd())
	cmd.AddCommand(c.newQuantumBenchmarkCmd())

	return cmd
}

func (c *CLI) newQuantumCircuitCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "circuit",
		Short: "Manage quantum circuits",
		Long:  "Submit and get quantum circuits",
	}

	cmd.AddCommand(c.newQuantumCircuitSubmitCmd())
	cmd.AddCommand(c.newQuantumCircuitGetCmd())

	return cmd
}

func (c *CLI) newQuantumCircuitSubmitCmd() *cobra.Command {
	var (
		name           string
		description    string
		qubitCount     int
		depth          int
		shots          int
		circuitCode    string
		circuitFile    string
		backend        string
		optimization   int
		errorMitigation bool
		wait           bool
		waitTimeout    time.Duration
	)

	cmd := &cobra.Command{
		Use:   "submit",
		Short: "Submit a quantum circuit",
		Long:  "Submit a quantum circuit for execution",
		RunE: func(cmd *cobra.Command, args []string) error {
			input := quantum.CircuitSubmission{
				Name:            name,
				Description:     description,
				QubitCount:      qubitCount,
				Depth:           depth,
				Shots:           shots,
				CircuitCode:     circuitCode,
				Backend:         backend,
				Optimization:    optimization,
				ErrorMitigation: errorMitigation,
			}

			if circuitFile != "" {
				data, err := os.ReadFile(circuitFile)
				if err != nil {
					return fmt.Errorf("reading circuit file: %w", err)
				}
				input.CircuitCode = string(data)
			}

			var status quantum.CircuitStatus
			if err := c.apiPost("/api/v1/quantum/circuits", input, &status); err != nil {
				return err
			}

			fmt.Printf("Circuit submitted:\n")
			c.printCircuitStatus(&status)

			if wait {
				fmt.Printf("\nWaiting for completion (timeout: %v)...\n", waitTimeout)
				return c.waitForCircuit(status.ID, waitTimeout)
			}

			return nil
		},
	}

	cmd.Flags().StringVarP(&name, "name", "n", "", "Circuit name")
	cmd.Flags().StringVarP(&description, "description", "d", "", "Circuit description")
	cmd.Flags().IntVar(&qubitCount, "qubits", 5, "Number of qubits")
	cmd.Flags().IntVar(&depth, "depth", 10, "Circuit depth")
	cmd.Flags().IntVar(&shots, "shots", 1024, "Number of shots")
	cmd.Flags().StringVar(&circuitCode, "code", "", "Circuit code (OpenQASM)")
	cmd.Flags().StringVar(&circuitFile, "file", "", "File containing circuit code")
	cmd.Flags().StringVar(&backend, "backend", "simulator", "Backend to use (simulator, ibmq_qasm_simulator, etc.)")
	cmd.Flags().IntVar(&optimization, "optimization", 1, "Optimization level (0-3)")
	cmd.Flags().BoolVar(&errorMitigation, "error-mitigation", true, "Enable error mitigation")
	cmd.Flags().BoolVarP(&wait, "wait", "w", false, "Wait for circuit completion")
	cmd.Flags().DurationVar(&waitTimeout, "timeout", 10*time.Minute, "Timeout for waiting")

	return cmd
}

func (c *CLI) newQuantumCircuitGetCmd() *cobra.Command {
	var showResult bool

	cmd := &cobra.Command{
		Use:   "get [circuit-id]",
		Short: "Get circuit status and results",
		Long:  "Get the status and results of a submitted circuit",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			circuitID := args[0]

			var status quantum.CircuitStatus
			if err := c.apiGet("/api/v1/quantum/circuits/"+circuitID+"/status", nil, &status); err != nil {
				return err
			}

			fmt.Printf("Circuit Status:\n")
			c.printCircuitStatus(&status)

			if showResult || status.Status == quantum.CircuitStatusCompleted {
				var result quantum.CircuitResult
				if err := c.apiGet("/api/v1/quantum/circuits/"+circuitID, nil, &result); err == nil {
					fmt.Printf("\nResults:\n")
					c.printCircuitResult(&result)
				}
			}

			return nil
		},
	}

	cmd.Flags().BoolVarP(&showResult, "result", "r", false, "Show results if available")

	return cmd
}

func (c *CLI) newQuantumListCmd() *cobra.Command {
	var (
		limit  int
		offset int
	)

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List quantum circuits",
		Long:  "List all submitted quantum circuits",
		RunE: func(cmd *cobra.Command, args []string) error {
			queryParams := make(map[string]string)
			if limit > 0 {
				queryParams["limit"] = strconv.Itoa(limit)
			}
			if offset > 0 {
				queryParams["offset"] = strconv.Itoa(offset)
			}

			var result struct {
				Circuits []quantum.CircuitStatus `json:"circuits"`
			}

			if err := c.apiGet("/api/v1/quantum/circuits", queryParams, &result); err != nil {
				return err
			}

			if len(result.Circuits) == 0 {
				fmt.Println("No circuits found")
				return nil
			}

			fmt.Printf("Found %d circuits:\n\n", len(result.Circuits))
			for i := range result.Circuits {
				c.printCircuitStatus(&result.Circuits[i])
				if i < len(result.Circuits)-1 {
					fmt.Println("---")
				}
			}

			return nil
		},
	}

	cmd.Flags().IntVar(&limit, "limit", 100, "Maximum number of results")
	cmd.Flags().IntVar(&offset, "offset", 0, "Offset for pagination")

	return cmd
}

func (c *CLI) newQuantumEstimateCmd() *cobra.Command {
	var (
		qubitCount int
		depth      int
		shots      int
		backend    string
	)

	cmd := &cobra.Command{
		Use:   "estimate",
		Short: "Estimate circuit cost",
		Long:  "Estimate the cost of running a quantum circuit",
		RunE: func(cmd *cobra.Command, args []string) error {
			input := quantum.CircuitSubmission{
				QubitCount: qubitCount,
				Depth:      depth,
				Shots:      shots,
				Backend:    backend,
			}

			var result map[string]interface{}
			if err := c.apiPost("/api/v1/quantum/estimate", input, &result); err != nil {
				return err
			}

			data, _ := json.MarshalIndent(result, "", "  ")
			fmt.Println(string(data))

			return nil
		},
	}

	cmd.Flags().IntVar(&qubitCount, "qubits", 5, "Number of qubits")
	cmd.Flags().IntVar(&depth, "depth", 10, "Circuit depth")
	cmd.Flags().IntVar(&shots, "shots", 1024, "Number of shots")
	cmd.Flags().StringVar(&backend, "backend", "simulator", "Backend to use")

	return cmd
}

func (c *CLI) newQuantumBenchmarkCmd() *cobra.Command {
	var (
		benchmarkType string
		qubits        int
		depth         int
		shots         int
		wait          bool
	)

	cmd := &cobra.Command{
		Use:   "benchmark",
		Short: "Run quantum benchmarks",
		Long:  "Run standard quantum computing benchmarks",
		RunE: func(cmd *cobra.Command, args []string) error {
			input := map[string]interface{}{
				"benchmark_type": benchmarkType,
				"qubits":         qubits,
				"depth":          depth,
				"shots":          shots,
			}

			var result struct {
				CircuitID string `json:"circuit_id"`
				Status    string `json:"status"`
			}
			if err := c.apiPost("/api/v1/quantum/benchmark", input, &result); err != nil {
				return err
			}

			fmt.Printf("Benchmark submitted:\n")
			fmt.Printf("  Circuit ID: %s\n", result.CircuitID)
			fmt.Printf("  Status:     %s\n", result.Status)
			fmt.Printf("  Type:       %s\n", benchmarkType)
			fmt.Printf("  Qubits:     %d\n", qubits)
			fmt.Printf("  Depth:      %d\n", depth)
			fmt.Printf("  Shots:      %d\n", shots)

			if wait {
				fmt.Printf("\nWaiting for completion...\n")
				return c.waitForCircuit(result.CircuitID, 30*time.Minute)
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&benchmarkType, "type", "random", "Benchmark type (random, ghz, qft, vqe, grover)")
	cmd.Flags().IntVar(&qubits, "qubits", 10, "Number of qubits")
	cmd.Flags().IntVar(&depth, "depth", 20, "Circuit depth")
	cmd.Flags().IntVar(&shots, "shots", 8192, "Number of shots")
	cmd.Flags().BoolVarP(&wait, "wait", "w", false, "Wait for benchmark completion")

	return cmd
}

func (c *CLI) printCircuitStatus(s *quantum.CircuitStatus) {
	fmt.Printf("  ID:           %s\n", s.ID)
	fmt.Printf("  Status:       %s\n", s.Status)
	fmt.Printf("  Backend:      %s\n", s.Backend)
	fmt.Printf("  Qubits:       %d\n", s.QubitCount)
	fmt.Printf("  Shots:        %d\n", s.Shots)
	if s.QueuePosition > 0 {
		fmt.Printf("  Queue Pos:    %d\n", s.QueuePosition)
	}
	if s.Progress > 0 {
		fmt.Printf("  Progress:     %.1f%%\n", s.Progress*100)
	}
	if s.EstimatedTimeLeft > 0 {
		fmt.Printf("  ETA:          %.1fs\n", s.EstimatedTimeLeft)
	}
	if s.Error != "" {
		fmt.Printf("  Error:        %s\n", s.Error)
	}
	fmt.Printf("  Created:      %s\n", s.CreatedAt.Format("2006-01-02 15:04:05"))
	if s.StartedAt != nil {
		fmt.Printf("  Started:      %s\n", s.StartedAt.Format("2006-01-02 15:04:05"))
	}
	if s.CompletedAt != nil {
		fmt.Printf("  Completed:    %s\n", s.CompletedAt.Format("2006-01-02 15:04:05"))
	}
}

func (c *CLI) printCircuitResult(r *quantum.CircuitResult) {
	fmt.Printf("  ID:           %s\n", r.ID)
	fmt.Printf("  Status:       %s\n", r.Status)
	fmt.Printf("  Shots:        %d\n", r.NumberOfShots)
	fmt.Printf("  Exec Time:    %.3fs\n", r.ExecutionTime)
	fmt.Printf("  Backend:      %s\n", r.Backend)
	fmt.Printf("  Opt Level:    %d\n", r.OptimizationLevel)
	fmt.Printf("  Error Mit:    %v\n", r.ErrorMitigationApplied)

	if len(r.Counts) > 0 {
		fmt.Printf("\n  Results (top 10):\n")
		i := 0
		for k, v := range r.Counts {
			if i >= 10 {
				break
			}
			prob := r.Probabilities[k]
			fmt.Printf("    %s: %d (%.2f%%)\n", k, v, prob*100)
			i++
		}
		if len(r.Counts) > 10 {
			fmt.Printf("    ... and %d more\n", len(r.Counts)-10)
		}
	}

	if len(r.ExpectationValues) > 0 {
		fmt.Printf("\n  Expectation Values:\n")
		for k, v := range r.ExpectationValues {
			fmt.Printf("    %s: %.6f\n", k, v)
		}
	}
}

func (c *CLI) waitForCircuit(circuitID string, timeout time.Duration) error {
	return c.WaitForStatus(context.Background(),
		func() (bool, error) {
			var status quantum.CircuitStatus
			if err := c.apiGet("/api/v1/quantum/circuits/"+circuitID+"/status", nil, &status); err != nil {
				return false, err
			}

			switch status.Status {
			case quantum.CircuitStatusCompleted:
				fmt.Printf("\nCircuit completed:\n")
				c.printCircuitStatus(&status)

				var result quantum.CircuitResult
				if err := c.apiGet("/api/v1/quantum/circuits/"+circuitID, nil, &result); err == nil {
					fmt.Printf("\nResults:\n")
					c.printCircuitResult(&result)
				}
				return true, nil

			case quantum.CircuitStatusFailed, quantum.CircuitStatusCancelled:
				return false, fmt.Errorf("circuit %s: %s", status.Status, status.Error)

			case quantum.CircuitStatusQueued, quantum.CircuitStatusRunning:
				if status.Status == quantum.CircuitStatusQueued && status.QueuePosition > 0 {
					fmt.Printf("\r  In queue (position: %d)...  ", status.QueuePosition)
				} else if status.Progress > 0 {
					fmt.Printf("\r  Running (%.1f%% complete)...  ", status.Progress*100)
				} else {
					fmt.Printf("\r  %s...  ", status.Status)
				}
				return false, nil
			}

			return false, nil
		},
		2*time.Second,
		timeout,
	)
}
