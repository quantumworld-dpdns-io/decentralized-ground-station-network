package scheduling

import (
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/stations"
)

type SlotStatus string

const (
	SlotStatusAvailable SlotStatus = "available"
	SlotStatusReserved  SlotStatus = "reserved"
	SlotStatusConfirmed SlotStatus = "confirmed"
	SlotStatusInProgress SlotStatus = "in_progress"
	SlotStatusCompleted SlotStatus = "completed"
	SlotStatusCancelled SlotStatus = "cancelled"
	SlotStatusFailed    SlotStatus = "failed"
)

type Priority int

const (
	PriorityLow    Priority = 0
	PriorityNormal Priority = 1
	PriorityHigh   Priority = 2
	PriorityCritical Priority = 3
)

type ScheduleSlot struct {
	ID          string        `json:"id"`
	StationID   string        `json:"station_id"`
	StationName string        `json:"station_name,omitempty"`
	OwnerID     string        `json:"owner_id"`
	StartTime   time.Time     `json:"start_time"`
	EndTime     time.Time     `json:"end_time"`
	Status      SlotStatus    `json:"status"`
	Priority    Priority      `json:"priority"`
	TaskType    string        `json:"task_type,omitempty"`
	SatelliteID string        `json:"satellite_id,omitempty"`
	Capability  stations.CapabilityType `json:"capability,omitempty"`
	AssignedTo  string        `json:"assigned_to,omitempty"`
	Metadata    map[string]string `json:"metadata,omitempty"`
	CreatedAt   time.Time     `json:"created_at"`
	UpdatedAt   time.Time     `json:"updated_at"`
}

type Assignment struct {
	ID         string    `json:"id"`
	SlotID     string    `json:"slot_id"`
	UserID     string    `json:"user_id"`
	StationID  string    `json:"station_id"`
	SatelliteID string   `json:"satellite_id,omitempty"`
	StartTime  time.Time `json:"start_time"`
	EndTime    time.Time `json:"end_time"`
	Status     SlotStatus `json:"status"`
	Priority   Priority  `json:"priority"`
	TaskType   string    `json:"task_type,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

type CreateSlotInput struct {
	StationID   string            `json:"station_id" validate:"required"`
	StartTime   time.Time         `json:"start_time" validate:"required"`
	EndTime     time.Time         `json:"end_time" validate:"required"`
	Priority    Priority          `json:"priority"`
	TaskType    string            `json:"task_type"`
	SatelliteID string            `json:"satellite_id"`
	Capability  stations.CapabilityType `json:"capability"`
	Metadata    map[string]string `json:"metadata,omitempty"`
}

type ScheduleFilter struct {
	StationID string      `json:"station_id,omitempty"`
	Status    *SlotStatus `json:"status,omitempty"`
	FromTime  *time.Time  `json:"from_time,omitempty"`
	ToTime    *time.Time  `json:"to_time,omitempty"`
	OwnerID   string      `json:"owner_id,omitempty"`
	Limit     int         `json:"limit,omitempty"`
	Offset    int         `json:"offset,omitempty"`
}

type Conflict struct {
	Type          string `json:"type"`
	Message       string `json:"message"`
	ConflictingID string `json:"conflicting_id"`
	Severity      string `json:"severity"`
}

type ScheduleResult struct {
	Slot      *ScheduleSlot `json:"slot"`
	Conflicts []Conflict    `json:"conflicts,omitempty"`
	Score     float64       `json:"score,omitempty"`
}

type CalendarEntry struct {
	Date        string        `json:"date"`
	Slots       []*ScheduleSlot `json:"slots"`
	TotalSlots  int           `json:"total_slots"`
	UsedSlots   int           `json:"used_slots"`
	Utilization float64       `json:"utilization"`
}
