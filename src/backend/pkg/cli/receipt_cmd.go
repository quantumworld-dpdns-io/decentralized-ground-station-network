package cli

import (
	"encoding/csv"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"github.com/quantumworld-dpdns-io/dgsn/internal/receipts"
)

func (c *CLI) newReceiptCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "receipt",
		Short: "Manage data receipts",
		Long:  "Create, verify, list, and export data receipts",
	}

	cmd.AddCommand(c.newReceiptCreateCmd())
	cmd.AddCommand(c.newReceiptVerifyCmd())
	cmd.AddCommand(c.newReceiptGetCmd())
	cmd.AddCommand(c.newReceiptListCmd())
	cmd.AddCommand(c.newReceiptExportCmd())

	return cmd
}

func (c *CLI) newReceiptCreateCmd() *cobra.Command {
	var (
		stationID  string
		scheduleID string
		taskID     string
		signalID   string
		proofType  string
		proofValue string
		algorithm  string
		publicKey  string
		nonce      string
	)

	cmd := &cobra.Command{
		Use:   "create",
		Short: "Create a new receipt",
		Long:  "Create a new data receipt for verification",
		RunE: func(cmd *cobra.Command, args []string) error {
			input := receipts.CreateReceiptInput{
				StationID:  stationID,
				ScheduleID: scheduleID,
				TaskID:     taskID,
				SignalID:   signalID,
				Proof: receipts.ProofData{
					Type:      receipts.ProofType(proofType),
					Algorithm: algorithm,
					Value:     proofValue,
					PublicKey: publicKey,
					Nonce:     nonce,
				},
			}

			var receipt receipts.Receipt
			if err := c.apiPost("/api/v1/receipts", input, &receipt); err != nil {
				return err
			}

			c.printReceipt(&receipt)
			return nil
		},
	}

	cmd.Flags().StringVar(&stationID, "station-id", "", "Station ID (required)")
	cmd.Flags().StringVar(&scheduleID, "schedule-id", "", "Schedule ID")
	cmd.Flags().StringVar(&taskID, "task-id", "", "Task ID")
	cmd.Flags().StringVar(&signalID, "signal-id", "", "Signal ID")
	cmd.Flags().StringVar(&proofType, "proof-type", "signature", "Proof type (signature, merkle, hashchain, hybrid)")
	cmd.Flags().StringVar(&proofValue, "proof-value", "", "Proof value/data (required)")
	cmd.Flags().StringVar(&algorithm, "algorithm", "ML-DSA-65", "Cryptographic algorithm")
	cmd.Flags().StringVar(&publicKey, "public-key", "", "Public key for verification")
	cmd.Flags().StringVar(&nonce, "nonce", "", "Nonce value")

	cmd.MarkFlagRequired("station-id")
	cmd.MarkFlagRequired("proof-value")

	return cmd
}

func (c *CLI) newReceiptVerifyCmd() *cobra.Command {
	var (
		receiptID  string
		stationID  string
		proofValue string
		publicKey  string
	)

	cmd := &cobra.Command{
		Use:   "verify",
		Short: "Verify a receipt",
		Long:  "Verify a receipt's authenticity and chain integrity",
		RunE: func(cmd *cobra.Command, args []string) error {
			input := receipts.VerifyReceiptInput{
				ReceiptID:  receiptID,
				StationID:  stationID,
				ProofValue: proofValue,
				PublicKey:  publicKey,
			}

			var result receipts.VerificationResult
			if err := c.apiPost("/api/v1/receipts/verify", input, &result); err != nil {
				return err
			}

			fmt.Printf("Receipt ID:    %s\n", result.ReceiptID)
			fmt.Printf("Valid:         %v\n", result.IsValid)
			fmt.Printf("Verified At:   %s\n", result.VerifiedAt.Format("2006-01-02 15:04:05"))
			if result.ErrorMessage != "" {
				fmt.Printf("Error:         %s\n", result.ErrorMessage)
			}
			if result.ChainStatus != "" {
				fmt.Printf("Chain Status:  %s\n", result.ChainStatus)
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&receiptID, "receipt-id", "", "Receipt ID (required)")
	cmd.Flags().StringVar(&stationID, "station-id", "", "Station ID (required)")
	cmd.Flags().StringVar(&proofValue, "proof-value", "", "Proof value (required)")
	cmd.Flags().StringVar(&publicKey, "public-key", "", "Public key (required)")

	cmd.MarkFlagRequired("receipt-id")
	cmd.MarkFlagRequired("station-id")
	cmd.MarkFlagRequired("proof-value")
	cmd.MarkFlagRequired("public-key")

	return cmd
}

func (c *CLI) newReceiptGetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "get [receipt-id]",
		Short: "Get a specific receipt",
		Long:  "Get detailed information about a specific receipt",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			receiptID := args[0]

			var receipt receipts.Receipt
			if err := c.apiGet("/api/v1/receipts/"+receiptID, nil, &receipt); err != nil {
				return err
			}

			c.printReceipt(&receipt)
			return nil
		},
	}
}

func (c *CLI) newReceiptListCmd() *cobra.Command {
	var (
		stationID string
		status    string
		fromDate  string
		toDate    string
		limit     int
		offset    int
	)

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List all receipts",
		Long:  "List receipts with optional filtering",
		RunE: func(cmd *cobra.Command, args []string) error {
			queryParams := make(map[string]string)
			if stationID != "" {
				queryParams["station_id"] = stationID
			}
			if status != "" {
				queryParams["status"] = status
			}
			if fromDate != "" {
				queryParams["from_date"] = fromDate
			}
			if toDate != "" {
				queryParams["to_date"] = toDate
			}
			if limit > 0 {
				queryParams["limit"] = strconv.Itoa(limit)
			}
			if offset > 0 {
				queryParams["offset"] = strconv.Itoa(offset)
			}

			var result struct {
				Receipts []receipts.Receipt `json:"receipts"`
				Pagination struct {
					Limit  int `json:"limit"`
					Offset int `json:"offset"`
					Count  int `json:"count"`
				} `json:"pagination"`
			}

			if err := c.apiGet("/api/v1/receipts", queryParams, &result); err != nil {
				return err
			}

			if len(result.Receipts) == 0 {
				fmt.Println("No receipts found")
				return nil
			}

			fmt.Printf("Found %d receipts:\n\n", result.Pagination.Count)
			for i := range result.Receipts {
				c.printReceipt(&result.Receipts[i])
				if i < len(result.Receipts)-1 {
					fmt.Println("---")
				}
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&stationID, "station-id", "", "Filter by station ID")
	cmd.Flags().StringVar(&status, "status", "", "Filter by status (pending, verified, invalid, disputed, anchored)")
	cmd.Flags().StringVar(&fromDate, "from-date", "", "Filter from date (RFC3339 format)")
	cmd.Flags().StringVar(&toDate, "to-date", "", "Filter to date (RFC3339 format)")
	cmd.Flags().IntVar(&limit, "limit", 100, "Maximum number of results")
	cmd.Flags().IntVar(&offset, "offset", 0, "Offset for pagination")

	return cmd
}

func (c *CLI) newReceiptExportCmd() *cobra.Command {
	var (
		stationID string
		status    string
		fromDate  string
		toDate    string
		format    string
		output    string
	)

	cmd := &cobra.Command{
		Use:   "export",
		Short: "Export receipts",
		Long:  "Export receipts to various formats (json, csv, jsonl)",
		RunE: func(cmd *cobra.Command, args []string) error {
			queryParams := make(map[string]string)
			if stationID != "" {
				queryParams["station_id"] = stationID
			}
			if status != "" {
				queryParams["status"] = status
			}
			if fromDate != "" {
				queryParams["from_date"] = fromDate
			}
			if toDate != "" {
				queryParams["to_date"] = toDate
			}
			if format != "" {
				queryParams["format"] = format
			}
			queryParams["limit"] = "10000"

			var result struct {
				Receipts []receipts.Receipt `json:"receipts"`
			}

			if err := c.apiGet("/api/v1/receipts", queryParams, &result); err != nil {
				return err
			}

			if len(result.Receipts) == 0 {
				fmt.Println("No receipts to export")
				return nil
			}

			var out io.Writer
			if output != "" {
				file, err := os.Create(output)
				if err != nil {
					return fmt.Errorf("creating output file: %w", err)
				}
				defer file.Close()
				out = file
				fmt.Printf("Exporting %d receipts to %s...\n", len(result.Receipts), output)
			} else {
				out = os.Stdout
			}

			switch strings.ToLower(format) {
			case "csv":
				return c.exportCSV(out, result.Receipts)
			case "jsonl":
				return c.exportJSONL(out, result.Receipts)
			default:
				enc := json.NewEncoder(out)
				enc.SetIndent("", "  ")
				return enc.Encode(result.Receipts)
			}
		},
	}

	cmd.Flags().StringVar(&stationID, "station-id", "", "Filter by station ID")
	cmd.Flags().StringVar(&status, "status", "", "Filter by status")
	cmd.Flags().StringVar(&fromDate, "from-date", "", "Filter from date")
	cmd.Flags().StringVar(&toDate, "to-date", "", "Filter to date")
	cmd.Flags().StringVarP(&format, "format", "f", "json", "Output format (json, csv, jsonl)")
	cmd.Flags().StringVarP(&output, "output", "o", "", "Output file path (default: stdout)")

	return cmd
}

func (c *CLI) printReceipt(r *receipts.Receipt) {
	fmt.Printf("ID:             %s\n", r.ID)
	fmt.Printf("Station ID:     %s\n", r.StationID)
	if r.ScheduleID != "" {
		fmt.Printf("Schedule ID:    %s\n", r.ScheduleID)
	}
	if r.TaskID != "" {
		fmt.Printf("Task ID:        %s\n", r.TaskID)
	}
	if r.SignalID != "" {
		fmt.Printf("Signal ID:      %s\n", r.SignalID)
	}
	fmt.Printf("Status:         %s\n", r.Status)
	fmt.Printf("Chain Position: %d\n", r.ChainPosition)
	if r.PrevReceiptID != "" {
		fmt.Printf("Previous:       %s\n", r.PrevReceiptID)
	}
	if r.MerkleRoot != "" {
		fmt.Printf("Merkle Root:    %s\n", r.MerkleRoot)
	}
	fmt.Printf("Proof Type:     %s\n", r.Proof.Type)
	fmt.Printf("Proof Algorithm:%s\n", r.Proof.Algorithm)
	fmt.Printf("Created:        %s\n", r.CreatedAt.Format("2006-01-02 15:04:05"))
	if r.VerifiedAt != nil {
		fmt.Printf("Verified:       %s\n", r.VerifiedAt.Format("2006-01-02 15:04:05"))
	}
}

func (c *CLI) exportCSV(out io.Writer, receipts []receipts.Receipt) error {
	writer := csv.NewWriter(out)
	defer writer.Flush()

	headers := []string{
		"id", "station_id", "schedule_id", "task_id", "signal_id",
		"status", "proof_type", "chain_position", "created_at", "verified_at",
	}
	if err := writer.Write(headers); err != nil {
		return err
	}

	for _, r := range receipts {
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
			strconv.FormatInt(r.ChainPosition, 10),
			r.CreatedAt.Format(time.RFC3339),
			verifiedAt,
		}
		if err := writer.Write(row); err != nil {
			return err
		}
	}

	return nil
}

func (c *CLI) exportJSONL(out io.Writer, receipts []receipts.Receipt) error {
	enc := json.NewEncoder(out)
	for _, r := range receipts {
		if err := enc.Encode(r); err != nil {
			return err
		}
	}
	return nil
}

import (
	"encoding/json"
	"io"
)
