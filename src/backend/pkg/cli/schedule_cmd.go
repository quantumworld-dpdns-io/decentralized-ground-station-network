package cli

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"github.com/quantumworld-dpdns-io/dgsn/internal/scheduling"
	"github.com/quantumworld-dpdns-io/dgsn/internal/stations"
)

func (c *CLI) newScheduleCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "schedule",
		Short: "Manage scheduling",
		Long:  "Create, list, assign, and release schedule slots",
	}

	cmd.AddCommand(c.newScheduleCreateCmd())
	cmd.AddCommand(c.newScheduleListCmd())
	cmd.AddCommand(c.newScheduleAssignCmd())
	cmd.AddCommand(c.newScheduleReleaseCmd())
	cmd.AddCommand(c.newScheduleConflictsCmd())

	return cmd
}

func (c *CLI) newScheduleCreateCmd() *cobra.Command {
	var (
		stationID   string
		startTime   string
		endTime     string
		priority    int
		taskType    string
		satelliteID string
		capability  string
	)

	cmd := &cobra.Command{
		Use:   "create",
		Short: "Create a schedule slot",
		Long:  "Create a new schedule slot for a ground station",
		RunE: func(cmd *cobra.Command, args []string) error {
			start, err := parseTime(startTime)
			if err != nil {
				return fmt.Errorf("parsing start time: %w", err)
			}

			end, err := parseTime(endTime)
			if err != nil {
				return fmt.Errorf("parsing end time: %w", err)
			}

			input := scheduling.CreateSlotInput{
				StationID:   stationID,
				StartTime:   start,
				EndTime:     end,
				Priority:    scheduling.Priority(priority),
				TaskType:    taskType,
				SatelliteID: satelliteID,
				Capability:  stations.CapabilityType(capability),
			}

			var slot scheduling.ScheduleSlot
			if err := c.apiPost("/api/v1/schedule/slots", input, &slot); err != nil {
				return err
			}

			c.printScheduleSlot(&slot)
			return nil
		},
	}

	cmd.Flags().StringVar(&stationID, "station-id", "", "Station ID (required)")
	cmd.Flags().StringVar(&startTime, "start", "", "Start time (RFC3339 or 'now', 'now+1h', etc.) (required)")
	cmd.Flags().StringVar(&endTime, "end", "", "End time (RFC3339 or 'now+2h', etc.) (required)")
	cmd.Flags().IntVar(&priority, "priority", 1, "Priority (0=low, 1=normal, 2=high, 3=critical)")
	cmd.Flags().StringVar(&taskType, "task-type", "", "Task type (observation, downlink, uplink, calibration)")
	cmd.Flags().StringVar(&satelliteID, "satellite-id", "", "Satellite ID")
	cmd.Flags().StringVar(&capability, "capability", "", "Capability type (s_band, x_band, ka_band, optical, quantum)")

	cmd.MarkFlagRequired("station-id")
	cmd.MarkFlagRequired("start")
	cmd.MarkFlagRequired("end")

	return cmd
}

func (c *CLI) newScheduleListCmd() *cobra.Command {
	var (
		stationID string
		status    string
		fromTime  string
		toTime    string
		ownerID   string
		limit     int
		offset    int
	)

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List schedule slots",
		Long:  "List schedule slots with optional filtering",
		RunE: func(cmd *cobra.Command, args []string) error {
			queryParams := make(map[string]string)
			if stationID != "" {
				queryParams["station_id"] = stationID
			}
			if status != "" {
				queryParams["status"] = status
			}
			if fromTime != "" {
				t, err := parseTime(fromTime)
				if err != nil {
					return fmt.Errorf("parsing from time: %w", err)
				}
				queryParams["from_time"] = t.Format(time.RFC3339)
			}
			if toTime != "" {
				t, err := parseTime(toTime)
				if err != nil {
					return fmt.Errorf("parsing to time: %w", err)
				}
				queryParams["to_time"] = t.Format(time.RFC3339)
			}
			if ownerID != "" {
				queryParams["owner_id"] = ownerID
			}
			if limit > 0 {
				queryParams["limit"] = strconv.Itoa(limit)
			}
			if offset > 0 {
				queryParams["offset"] = strconv.Itoa(offset)
			}

			var result struct {
				Slots []scheduling.ScheduleSlot `json:"slots"`
				Pagination struct {
					Limit  int `json:"limit"`
					Offset int `json:"offset"`
					Count  int `json:"count"`
				} `json:"pagination"`
			}

			if err := c.apiGet("/api/v1/schedule/slots", queryParams, &result); err != nil {
				return err
			}

			if len(result.Slots) == 0 {
				fmt.Println("No schedule slots found")
				return nil
			}

			fmt.Printf("Found %d slots:\n\n", result.Pagination.Count)
			for i := range result.Slots {
				c.printScheduleSlot(&result.Slots[i])
				if i < len(result.Slots)-1 {
					fmt.Println("---")
				}
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&stationID, "station-id", "", "Filter by station ID")
	cmd.Flags().StringVar(&status, "status", "", "Filter by status (available, reserved, confirmed, in_progress, completed, cancelled, failed)")
	cmd.Flags().StringVar(&fromTime, "from", "", "Filter from time")
	cmd.Flags().StringVar(&toTime, "to", "", "Filter to time")
	cmd.Flags().StringVar(&ownerID, "owner-id", "", "Filter by owner ID")
	cmd.Flags().IntVar(&limit, "limit", 100, "Maximum number of results")
	cmd.Flags().IntVar(&offset, "offset", 0, "Offset for pagination")

	return cmd
}

func (c *CLI) newScheduleAssignCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "assign [slot-id]",
		Short: "Assign a schedule slot",
		Long:  "Assign a schedule slot to yourself",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			slotID := args[0]

			var assignment scheduling.Assignment
			if err := c.apiPost("/api/v1/schedule/slots/"+slotID+"/assign", nil, &assignment); err != nil {
				return err
			}

			fmt.Printf("Slot assigned:\n")
			c.printAssignment(&assignment)
			return nil
		},
	}
}

func (c *CLI) newScheduleReleaseCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "release [slot-id]",
		Short: "Release a schedule slot",
		Long:  "Release an assigned schedule slot",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			slotID := args[0]

			var result map[string]interface{}
			if err := c.apiPost("/api/v1/schedule/slots/"+slotID+"/release", nil, &result); err != nil {
				return err
			}

			data, _ := json.MarshalIndent(result, "", "  ")
			fmt.Println(string(data))

			return nil
		},
	}
}

func (c *CLI) newScheduleConflictsCmd() *cobra.Command {
	var (
		stationID string
		fromTime  string
		toTime    string
	)

	cmd := &cobra.Command{
		Use:   "conflicts",
		Short: "List schedule conflicts",
		Long:  "Check for schedule conflicts",
		RunE: func(cmd *cobra.Command, args []string) error {
			queryParams := make(map[string]string)
			if stationID != "" {
				queryParams["station_id"] = stationID
			}
			if fromTime != "" {
				t, err := parseTime(fromTime)
				if err != nil {
					return fmt.Errorf("parsing from time: %w", err)
				}
				queryParams["from_time"] = t.Format(time.RFC3339)
			}
			if toTime != "" {
				t, err := parseTime(toTime)
				if err != nil {
					return fmt.Errorf("parsing to time: %w", err)
				}
				queryParams["to_time"] = t.Format(time.RFC3339)
			}

			var result struct {
				Conflicts []scheduling.Conflict `json:"conflicts"`
				Count     int                    `json:"count"`
			}

			if err := c.apiGet("/api/v1/schedule/conflicts", queryParams, &result); err != nil {
				return err
			}

			if len(result.Conflicts) == 0 {
				fmt.Println("No conflicts found")
				return nil
			}

			fmt.Printf("Found %d conflicts:\n\n", result.Count)
			for i, conflict := range result.Conflicts {
				fmt.Printf("[%d] Type:      %s\n", i, conflict.Type)
				fmt.Printf("    Message:   %s\n", conflict.Message)
				fmt.Printf("    Conflicts: %s\n", conflict.ConflictingID)
				fmt.Printf("    Severity:  %s\n", conflict.Severity)
				if i < len(result.Conflicts)-1 {
					fmt.Println()
				}
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&stationID, "station-id", "", "Check conflicts for station ID")
	cmd.Flags().StringVar(&fromTime, "from", "", "Check from time")
	cmd.Flags().StringVar(&toTime, "to", "", "Check to time")

	return cmd
}

func (c *CLI) printScheduleSlot(s *scheduling.ScheduleSlot) {
	fmt.Printf("ID:             %s\n", s.ID)
	fmt.Printf("Station ID:     %s\n", s.StationID)
	if s.StationName != "" {
		fmt.Printf("Station Name:   %s\n", s.StationName)
	}
	fmt.Printf("Owner ID:       %s\n", s.OwnerID)
	fmt.Printf("Start Time:     %s\n", s.StartTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("End Time:       %s\n", s.EndTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("Status:         %s\n", s.Status)
	fmt.Printf("Priority:       %s\n", priorityToString(s.Priority))
	if s.TaskType != "" {
		fmt.Printf("Task Type:      %s\n", s.TaskType)
	}
	if s.SatelliteID != "" {
		fmt.Printf("Satellite ID:   %s\n", s.SatelliteID)
	}
	if s.Capability != "" {
		fmt.Printf("Capability:     %s\n", s.Capability)
	}
	if s.AssignedTo != "" {
		fmt.Printf("Assigned To:    %s\n", s.AssignedTo)
	}
	fmt.Printf("Created:        %s\n", s.CreatedAt.Format("2006-01-02 15:04:05"))
	fmt.Printf("Updated:        %s\n", s.UpdatedAt.Format("2006-01-02 15:04:05"))
}

func (c *CLI) printAssignment(a *scheduling.Assignment) {
	fmt.Printf("ID:             %s\n", a.ID)
	fmt.Printf("Slot ID:        %s\n", a.SlotID)
	fmt.Printf("User ID:        %s\n", a.UserID)
	fmt.Printf("Station ID:     %s\n", a.StationID)
	if a.SatelliteID != "" {
		fmt.Printf("Satellite ID:   %s\n", a.SatelliteID)
	}
	fmt.Printf("Start Time:     %s\n", a.StartTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("End Time:       %s\n", a.EndTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("Status:         %s\n", a.Status)
	fmt.Printf("Priority:       %s\n", priorityToString(a.Priority))
	if a.TaskType != "" {
		fmt.Printf("Task Type:      %s\n", a.TaskType)
	}
	fmt.Printf("Created:        %s\n", a.CreatedAt.Format("2006-01-02 15:04:05"))
}

func priorityToString(p scheduling.Priority) string {
	switch p {
	case scheduling.PriorityLow:
		return "low"
	case scheduling.PriorityNormal:
		return "normal"
	case scheduling.PriorityHigh:
		return "high"
	case scheduling.PriorityCritical:
		return "critical"
	default:
		return fmt.Sprintf("unknown(%d)", p)
	}
}

func parseTime(s string) (time.Time, error) {
	s = strings.TrimSpace(s)

	if s == "now" {
		return time.Now(), nil
	}

	if strings.HasPrefix(s, "now+") {
		durationStr := s[4:]
		d, err := time.ParseDuration(durationStr)
		if err != nil {
			return time.Time{}, err
		}
		return time.Now().Add(d), nil
	}

	if strings.HasPrefix(s, "now-") {
		durationStr := s[4:]
		d, err := time.ParseDuration(durationStr)
		if err != nil {
			return time.Time{}, err
		}
		return time.Now().Add(-d), nil
	}

	formats := []string{
		time.RFC3339,
		time.RFC3339Nano,
		"2006-01-02 15:04:05",
		"2006-01-02",
		"2006/01/02 15:04:05",
		"2006/01/02",
	}

	for _, format := range formats {
		if t, err := time.ParseInLocation(format, s, time.Local); err == nil {
			return t, nil
		}
	}

	return time.Time{}, fmt.Errorf("unable to parse time: %s", s)
}
