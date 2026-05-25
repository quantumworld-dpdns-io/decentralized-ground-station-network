package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/spf13/cobra"
	"github.com/quantumworld-dpdns-io/dgsn/internal/stations"
)

func (c *CLI) newStationCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "station",
		Short: "Manage ground stations",
		Long:  "Register, list, get, update, and delete ground stations",
	}

	cmd.AddCommand(c.newStationRegisterCmd())
	cmd.AddCommand(c.newStationListCmd())
	cmd.AddCommand(c.newStationGetCmd())
	cmd.AddCommand(c.newStationUpdateCmd())
	cmd.AddCommand(c.newStationDeleteCmd())

	return cmd
}

func (c *CLI) newStationRegisterCmd() *cobra.Command {
	var (
		name            string
		latitude        float64
		longitude       float64
		altitude        float64
		locName         string
		capabilities    []string
		hardwareVersion string
		softwareVersion string
		publicKey       string
		ownerID         string
	)

	cmd := &cobra.Command{
		Use:   "register",
		Short: "Register a new ground station",
		Long:  "Register a new ground station with the network",
		RunE: func(cmd *cobra.Command, args []string) error {
			caps, err := parseCapabilities(capabilities)
			if err != nil {
				return fmt.Errorf("parsing capabilities: %w", err)
			}

			input := stations.RegisterStationInput{
				Name: name,
				Location: stations.Location{
					Latitude:  latitude,
					Longitude: longitude,
					Altitude:  altitude,
					Name:      locName,
				},
				Capabilities:    caps,
				HardwareVersion: hardwareVersion,
				SoftwareVersion: softwareVersion,
				PublicKey:       publicKey,
			}

			var station stations.Station
			if err := c.apiPost("/api/v1/stations", input, &station); err != nil {
				return err
			}

			c.printStation(&station)
			return nil
		},
	}

	cmd.Flags().StringVarP(&name, "name", "n", "", "Station name (required)")
	cmd.Flags().Float64Var(&latitude, "latitude", 0, "Latitude (required)")
	cmd.Flags().Float64Var(&longitude, "longitude", 0, "Longitude (required)")
	cmd.Flags().Float64Var(&altitude, "altitude", 0, "Altitude in meters")
	cmd.Flags().StringVar(&locName, "location-name", "", "Location name")
	cmd.Flags().StringSliceVarP(&capabilities, "capabilities", "c", []string{}, 
		"Capabilities (format: type=freq,bandwidth,data_rate,polarization,min_elevation,active)")
	cmd.Flags().StringVar(&hardwareVersion, "hardware-version", "", "Hardware version")
	cmd.Flags().StringVar(&softwareVersion, "software-version", "", "Software version")
	cmd.Flags().StringVar(&publicKey, "public-key", "", "Public key for verification (required)")
	cmd.Flags().StringVar(&ownerID, "owner-id", "", "Owner ID")

	cmd.MarkFlagRequired("name")
	cmd.MarkFlagRequired("latitude")
	cmd.MarkFlagRequired("longitude")
	cmd.MarkFlagRequired("public-key")

	return cmd
}

func (c *CLI) newStationListCmd() *cobra.Command {
	var (
		status   string
		capType  string
		verified bool
		ownerID  string
		limit    int
		offset   int
	)

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List all ground stations",
		Long:  "List registered ground stations with optional filtering",
		RunE: func(cmd *cobra.Command, args []string) error {
			queryParams := make(map[string]string)
			if status != "" {
				queryParams["status"] = status
			}
			if capType != "" {
				queryParams["capability"] = capType
			}
			if ownerID != "" {
				queryParams["owner_id"] = ownerID
			}
			if cmd.Flags().Changed("verified") {
				queryParams["verified"] = strconv.FormatBool(verified)
			}
			if limit > 0 {
				queryParams["limit"] = strconv.Itoa(limit)
			}
			if offset > 0 {
				queryParams["offset"] = strconv.Itoa(offset)
			}

			var result struct {
				Stations []stations.Station `json:"stations"`
				Pagination struct {
					Limit  int `json:"limit"`
					Offset int `json:"offset"`
					Count  int `json:"count"`
				} `json:"pagination"`
			}

			if err := c.apiGet("/api/v1/stations", queryParams, &result); err != nil {
				return err
			}

			if len(result.Stations) == 0 {
				fmt.Println("No stations found")
				return nil
			}

			fmt.Printf("Found %d stations:\n\n", result.Pagination.Count)
			for i := range result.Stations {
				c.printStation(&result.Stations[i])
				if i < len(result.Stations)-1 {
					fmt.Println("---")
				}
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&status, "status", "", "Filter by status (offline, online, busy, maintenance, error)")
	cmd.Flags().StringVar(&capType, "capability", "", "Filter by capability type")
	cmd.Flags().BoolVar(&verified, "verified", false, "Filter by verified status")
	cmd.Flags().StringVar(&ownerID, "owner-id", "", "Filter by owner ID")
	cmd.Flags().IntVar(&limit, "limit", 100, "Maximum number of results")
	cmd.Flags().IntVar(&offset, "offset", 0, "Offset for pagination")

	return cmd
}

func (c *CLI) newStationGetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "get [station-id]",
		Short: "Get a specific ground station",
		Long:  "Get detailed information about a specific ground station",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			stationID := args[0]

			var station stations.Station
			if err := c.apiGet("/api/v1/stations/"+stationID, nil, &station); err != nil {
				return err
			}

			c.printStation(&station)
			return nil
		},
	}
}

func (c *CLI) newStationUpdateCmd() *cobra.Command {
	var (
		name            *string
		latitude        *float64
		longitude       *float64
		altitude        *float64
		locName         *string
		status          *string
		hardwareVersion *string
		softwareVersion *string
	)

	cmd := &cobra.Command{
		Use:   "update [station-id]",
		Short: "Update a ground station",
		Long:  "Update an existing ground station's information",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			stationID := args[0]

			input := make(map[string]interface{})

			if name != nil {
				input["name"] = *name
			}
			if status != nil {
				input["status"] = *status
			}
			if hardwareVersion != nil {
				input["hardware_version"] = *hardwareVersion
			}
			if softwareVersion != nil {
				input["software_version"] = *softwareVersion
			}

			location := make(map[string]interface{})
			hasLocation := false
			if latitude != nil {
				location["latitude"] = *latitude
				hasLocation = true
			}
			if longitude != nil {
				location["longitude"] = *longitude
				hasLocation = true
			}
			if altitude != nil {
				location["altitude"] = *altitude
				hasLocation = true
			}
			if locName != nil {
				location["name"] = *locName
				hasLocation = true
			}
			if hasLocation {
				input["location"] = location
			}

			if len(input) == 0 {
				return fmt.Errorf("no fields specified for update")
			}

			var station stations.Station
			if err := c.apiPut("/api/v1/stations/"+stationID, input, &station); err != nil {
				return err
			}

			c.printStation(&station)
			return nil
		},
	}

	cmd.Flags().StringVar(&name, "name", "", "New station name")
	cmd.Flags().Float64Var(latitude, "latitude", 0, "New latitude")
	cmd.Flags().Float64Var(longitude, "longitude", 0, "New longitude")
	cmd.Flags().Float64Var(altitude, "altitude", 0, "New altitude")
	cmd.Flags().StringVar(&locName, "location-name", "", "New location name")
	cmd.Flags().StringVar(&status, "status", "", "New status")
	cmd.Flags().StringVar(&hardwareVersion, "hardware-version", "", "New hardware version")
	cmd.Flags().StringVar(&softwareVersion, "software-version", "", "New software version")

	return cmd
}

func (c *CLI) newStationDeleteCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "delete [station-id]",
		Short: "Delete a ground station",
		Long:  "Remove a ground station from the network",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			stationID := args[0]

			if err := c.apiDelete("/api/v1/stations/"+stationID, nil); err != nil {
				return err
			}

			fmt.Printf("Station %s deleted successfully\n", stationID)
			return nil
		},
	}
}

func (c *CLI) printStation(s *stations.Station) {
	fmt.Printf("ID:         %s\n", s.ID)
	fmt.Printf("Name:       %s\n", s.Name)
	fmt.Printf("Status:     %s\n", s.Status)
	fmt.Printf("Verified:   %v\n", s.IsVerified)
	fmt.Printf("Owner ID:   %s\n", s.OwnerID)
	fmt.Printf("Location:   %.6f, %.6f (alt: %.1fm)\n", 
		s.Location.Latitude, s.Location.Longitude, s.Location.Altitude)
	if s.Location.Name != "" {
		fmt.Printf("Loc Name:   %s\n", s.Location.Name)
	}
	if len(s.Capabilities) > 0 {
		fmt.Println("Capabilities:")
		for i, cap := range s.Capabilities {
			fmt.Printf("  [%d] Type: %s, Freq: %.2f MHz, BW: %.2f MHz, Rate: %.2f Mbps\n",
				i, cap.Type, cap.Frequency/1e6, cap.Bandwidth/1e6, cap.DataRate/1e6)
		}
	}
	if s.HardwareVersion != "" {
		fmt.Printf("HW Version: %s\n", s.HardwareVersion)
	}
	if s.SoftwareVersion != "" {
		fmt.Printf("SW Version: %s\n", s.SoftwareVersion)
	}
	fmt.Printf("Created:    %s\n", s.CreatedAt.Format("2006-01-02 15:04:05"))
	fmt.Printf("Updated:    %s\n", s.UpdatedAt.Format("2006-01-02 15:04:05"))
	if s.LastContactAt != nil {
		fmt.Printf("Last Seen:  %s\n", s.LastContactAt.Format("2006-01-02 15:04:05"))
	}
}

func parseCapabilities(capStrs []string) ([]stations.StationCapability, error) {
	var caps []stations.StationCapability

	for _, capStr := range capStrs {
		parts := strings.Split(capStr, ",")
		if len(parts) < 1 {
			return nil, fmt.Errorf("invalid capability format: %s", capStr)
		}

		cap := stations.StationCapability{
			Active: true,
		}

		for i, part := range parts {
			part = strings.TrimSpace(part)
			if i == 0 {
				cap.Type = stations.CapabilityType(part)
				continue
			}

			kv := strings.SplitN(part, "=", 2)
			if len(kv) != 2 {
				continue
			}
			key := strings.TrimSpace(kv[0])
			value := strings.TrimSpace(kv[1])

			switch key {
			case "freq", "frequency":
				if f, err := strconv.ParseFloat(value, 64); err == nil {
					cap.Frequency = f
				}
			case "bw", "bandwidth":
				if f, err := strconv.ParseFloat(value, 64); err == nil {
					cap.Bandwidth = f
				}
			case "rate", "data_rate":
				if f, err := strconv.ParseFloat(value, 64); err == nil {
					cap.DataRate = f
				}
			case "pol", "polarization":
				cap.Polarization = value
			case "min_elev", "min_elevation":
				if f, err := strconv.ParseFloat(value, 64); err == nil {
					cap.MinElevation = f
				}
			case "active":
				if b, err := strconv.ParseBool(value); err == nil {
					cap.Active = b
				}
			}
		}

		caps = append(caps, cap)
	}

	return caps, nil
}

func (c *CLI) apiGet(path string, params map[string]string, result interface{}) error {
	url := c.apiClient.Endpoint + path

	if len(params) > 0 {
		var parts []string
		for k, v := range params {
			parts = append(parts, fmt.Sprintf("%s=%s", k, v))
		}
		url += "?" + strings.Join(parts, "&")
	}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}

	if c.apiClient.APIKey != "" {
		req.Header.Set("X-API-Key", c.apiClient.APIKey)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API error (%d): %s", resp.StatusCode, string(body))
	}

	if result != nil {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("decoding response: %w", err)
		}
	}

	return nil
}

func (c *CLI) apiPost(path string, body, result interface{}) error {
	return c.doHTTPRequest("POST", path, body, result)
}

func (c *CLI) apiPut(path string, body, result interface{}) error {
	return c.doHTTPRequest("PUT", path, body, result)
}

func (c *CLI) apiDelete(path string, result interface{}) error {
	return c.doHTTPRequest("DELETE", path, nil, result)
}

func (c *CLI) doHTTPRequest(method, path string, body, result interface{}) error {
	url := c.apiClient.Endpoint + path

	var reqBody io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("marshaling request: %w", err)
		}
		reqBody = bytes.NewReader(data)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if c.apiClient.APIKey != "" {
		req.Header.Set("X-API-Key", c.apiClient.APIKey)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API error (%d): %s", resp.StatusCode, string(respBody))
	}

	if result != nil && resp.ContentLength != 0 {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("decoding response: %w", err)
		}
	}

	return nil
}
