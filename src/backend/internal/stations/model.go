package stations

import (
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/identity"
)

type StationStatus string

const (
	StationStatusOffline  StationStatus = "offline"
	StationStatusOnline   StationStatus = "online"
	StationStatusBusy     StationStatus = "busy"
	StationStatusMaintech StationStatus = "maintenance"
	StationStatusError    StationStatus = "error"
)

type CapabilityType string

const (
	CapabilityS band    CapabilityType = "s_band"
	CapabilityXBand    CapabilityType = "x_band"
	CapabilityKA Band   CapabilityType = "ka_band"
	CapabilityOptical  CapabilityType = "optical"
	CapabilityQuantum  CapabilityType = "quantum"
)

type Station struct {
	ID              string                 `json:"id"`
	OwnerID         string                 `json:"owner_id"`
	Name            string                 `json:"name"`
	Location        Location               `json:"location"`
	Capabilities    []StationCapability    `json:"capabilities"`
	Status          StationStatus          `json:"status"`
	IsVerified      bool                   `json:"is_verified"`
	HardwareVersion string                 `json:"hardware_version"`
	SoftwareVersion string                 `json:"software_version"`
	PublicKey       string                 `json:"public_key"`
	Owner           *identity.User         `json:"owner,omitempty"`
	Metadata        map[string]string      `json:"metadata,omitempty"`
	CreatedAt       time.Time              `json:"created_at"`
	UpdatedAt       time.Time              `json:"updated_at"`
	LastContactAt   *time.Time             `json:"last_contact_at,omitempty"`
}

type Location struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Altitude  float64 `json:"altitude"`
	Name      string  `json:"name,omitempty"`
}

type StationCapability struct {
	Type       CapabilityType `json:"type"`
	Frequency  float64        `json:"frequency"`
	Bandwidth  float64        `json:"bandwidth"`
	DataRate   float64        `json:"data_rate"`
	Polarization string       `json:"polarization,omitempty"`
	MinElevation float64      `json:"min_elevation"`
	Active       bool         `json:"active"`
}

type RegisterStationInput struct {
	Name            string              `json:"name" validate:"required,min=2,max=100"`
	Location        Location            `json:"location" validate:"required"`
	Capabilities    []StationCapability `json:"capabilities" validate:"required,min=1,dive"`
	HardwareVersion string              `json:"hardware_version"`
	SoftwareVersion string              `json:"software_version"`
	PublicKey       string              `json:"public_key" validate:"required"`
	Metadata        map[string]string   `json:"metadata,omitempty"`
}

type UpdateStationInput struct {
	Name            *string             `json:"name,omitempty"`
	Location        *Location           `json:"location,omitempty"`
	Capabilities    []StationCapability `json:"capabilities,omitempty"`
	Status          *StationStatus      `json:"status,omitempty"`
	HardwareVersion *string             `json:"hardware_version,omitempty"`
	SoftwareVersion *string             `json:"software_version,omitempty"`
	Metadata        *map[string]string  `json:"metadata,omitempty"`
}

type StationFilter struct {
	Status     *StationStatus  `json:"status,omitempty"`
	Capability *CapabilityType `json:"capability,omitempty"`
	Verified   *bool           `json:"verified,omitempty"`
	Near       *Location       `json:"near,omitempty"`
	RadiusKM   float64         `json:"radius_km,omitempty"`
	OwnerID    string          `json:"owner_id,omitempty"`
	Limit      int             `json:"limit,omitempty"`
	Offset     int             `json:"offset,omitempty"`
}
