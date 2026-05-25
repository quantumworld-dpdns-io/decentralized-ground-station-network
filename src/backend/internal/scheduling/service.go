package scheduling

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
)

type SlotRepository interface {
	Create(ctx context.Context, slot *ScheduleSlot) error
	GetByID(ctx context.Context, id string) (*ScheduleSlot, error)
	List(ctx context.Context, filter ScheduleFilter) ([]*ScheduleSlot, error)
	Update(ctx context.Context, slot *ScheduleSlot) error
	Delete(ctx context.Context, id string) error
}

type AssignmentRepository interface {
	Create(ctx context.Context, a *Assignment) error
	GetByID(ctx context.Context, id string) (*Assignment, error)
	ListByUser(ctx context.Context, userID string) ([]*Assignment, error)
	Update(ctx context.Context, a *Assignment) error
	Delete(ctx context.Context, id string) error
}

type SlotService interface {
	Create(ctx context.Context, input CreateSlotInput, ownerID string) (*ScheduleSlot, error)
	Get(ctx context.Context, id string) (*ScheduleSlot, error)
	List(ctx context.Context, filter ScheduleFilter) ([]*ScheduleSlot, error)
	Update(ctx context.Context, id string, input CreateSlotInput) (*ScheduleSlot, error)
	Delete(ctx context.Context, id string) error
	Assign(ctx context.Context, slotID, userID string) (*Assignment, error)
	Release(ctx context.Context, slotID string) error
	FindAvailable(ctx context.Context, from, to time.Time, capabilities []string) ([]*ScheduleSlot, error)
}

type slotService struct {
	slotRepo  SlotRepository
	assignRepo AssignmentRepository
	algo      Algorithm
	quantum   QuantumScheduler
}

func NewSlotService(slotRepo SlotRepository, assignRepo AssignmentRepository, algo Algorithm, quantum QuantumScheduler) SlotService {
	return &slotService{
		slotRepo:   slotRepo,
		assignRepo: assignRepo,
		algo:       algo,
		quantum:    quantum,
	}
}

func (s *slotService) Create(ctx context.Context, input CreateSlotInput, ownerID string) (*ScheduleSlot, error) {
	if !input.StartTime.Before(input.EndTime) {
		return nil, fmt.Errorf("start time must be before end time")
	}

	slot := &ScheduleSlot{
		ID:          uuid.New().String(),
		StationID:   input.StationID,
		OwnerID:     ownerID,
		StartTime:   input.StartTime,
		EndTime:     input.EndTime,
		Status:      SlotStatusAvailable,
		Priority:    input.Priority,
		TaskType:    input.TaskType,
		SatelliteID: input.SatelliteID,
		Capability:  input.Capability,
		Metadata:    input.Metadata,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}

	if err := s.slotRepo.Create(ctx, slot); err != nil {
		return nil, fmt.Errorf("creating schedule slot: %w", err)
	}

	return slot, nil
}

func (s *slotService) Get(ctx context.Context, id string) (*ScheduleSlot, error) {
	slot, err := s.slotRepo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting schedule slot: %w", err)
	}
	return slot, nil
}

func (s *slotService) List(ctx context.Context, filter ScheduleFilter) ([]*ScheduleSlot, error) {
	if filter.Limit <= 0 || filter.Limit > 1000 {
		filter.Limit = 100
	}
	slots, err := s.slotRepo.List(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("listing schedule slots: %w", err)
	}
	return slots, nil
}

func (s *slotService) Update(ctx context.Context, id string, input CreateSlotInput) (*ScheduleSlot, error) {
	slot, err := s.slotRepo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting slot for update: %w", err)
	}

	slot.StationID = input.StationID
	slot.StartTime = input.StartTime
	slot.EndTime = input.EndTime
	slot.Priority = input.Priority
	slot.TaskType = input.TaskType
	slot.SatelliteID = input.SatelliteID
	slot.Capability = input.Capability
	slot.Metadata = input.Metadata
	slot.UpdatedAt = time.Now().UTC()

	if err := s.slotRepo.Update(ctx, slot); err != nil {
		return nil, fmt.Errorf("updating schedule slot: %w", err)
	}

	return slot, nil
}

func (s *slotService) Delete(ctx context.Context, id string) error {
	if err := s.slotRepo.Delete(ctx, id); err != nil {
		return fmt.Errorf("deleting schedule slot: %w", err)
	}
	return nil
}

func (s *slotService) Assign(ctx context.Context, slotID, userID string) (*Assignment, error) {
	slot, err := s.slotRepo.GetByID(ctx, slotID)
	if err != nil {
		return nil, fmt.Errorf("getting slot for assignment: %w", err)
	}

	if slot.Status != SlotStatusAvailable {
		return nil, fmt.Errorf("slot %s is not available (status: %s)", slotID, slot.Status)
	}

	existingAssignments, err := s.assignRepo.ListByUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("checking existing assignments: %w", err)
	}
	for _, ea := range existingAssignments {
		if slot.StartTime.Before(ea.EndTime) && slot.EndTime.After(ea.StartTime) {
			return nil, fmt.Errorf("user %s already has an assignment during this time slot", userID)
		}
	}

	assignment := &Assignment{
		ID:         uuid.New().String(),
		SlotID:     slotID,
		UserID:     userID,
		StationID:  slot.StationID,
		SatelliteID: slot.SatelliteID,
		StartTime:  slot.StartTime,
		EndTime:    slot.EndTime,
		Status:     SlotStatusReserved,
		Priority:   slot.Priority,
		TaskType:   slot.TaskType,
		CreatedAt:  time.Now().UTC(),
	}

	if err := s.assignRepo.Create(ctx, assignment); err != nil {
		return nil, fmt.Errorf("creating assignment: %w", err)
	}

	slot.Status = SlotStatusReserved
	slot.AssignedTo = userID
	slot.UpdatedAt = time.Now().UTC()

	if err := s.slotRepo.Update(ctx, slot); err != nil {
		return nil, fmt.Errorf("updating slot status after assignment: %w", err)
	}

	return assignment, nil
}

func (s *slotService) Release(ctx context.Context, slotID string) error {
	slot, err := s.slotRepo.GetByID(ctx, slotID)
	if err != nil {
		return fmt.Errorf("getting slot for release: %w", err)
	}

	slot.Status = SlotStatusAvailable
	slot.AssignedTo = ""
	slot.UpdatedAt = time.Now().UTC()

	if err := s.slotRepo.Update(ctx, slot); err != nil {
		return fmt.Errorf("releasing slot: %w", err)
	}

	return nil
}

func (s *slotService) FindAvailable(ctx context.Context, from, to time.Time, capabilities []string) ([]*ScheduleSlot, error) {
	slots, err := s.slotRepo.List(ctx, ScheduleFilter{
		FromTime: &from,
		ToTime:   &to,
	})
	if err != nil {
		return nil, fmt.Errorf("finding available slots: %w", err)
	}

	var available []*ScheduleSlot
	for _, slot := range slots {
		if slot.Status != SlotStatusAvailable {
			continue
		}
		if len(capabilities) == 0 {
			available = append(available, slot)
		} else {
			for _, cap := range capabilities {
				if string(slot.Capability) == cap {
					available = append(available, slot)
					break
				}
			}
		}
	}

	return available, nil
}

func NewSlotRepository(db *sql.DB) SlotRepository {
	return &slotRepo{db: db}
}

type slotRepo struct {
	db *sql.DB
}

func (r *slotRepo) Create(ctx context.Context, slot *ScheduleSlot) error {
	metaJSON, _ := json.Marshal(slot.Metadata)
	query := `INSERT INTO schedule_slots (
		id, station_id, owner_id, start_time, end_time, status, priority,
		task_type, satellite_id, capability, assigned_to, metadata, created_at, updated_at
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`
	_, err := r.db.ExecContext(ctx, query,
		slot.ID, slot.StationID, slot.OwnerID, slot.StartTime, slot.EndTime,
		slot.Status, slot.Priority, nullIfEmpty(slot.TaskType),
		nullIfEmpty(slot.SatelliteID), slot.Capability, nullIfEmpty(slot.AssignedTo),
		string(metaJSON), slot.CreatedAt, slot.UpdatedAt)
	return err
}

func (r *slotRepo) GetByID(ctx context.Context, id string) (*ScheduleSlot, error) {
	slot := &ScheduleSlot{}
	var taskType, satelliteID, assignedTo, metaJSON sql.NullString
	query := `SELECT id, station_id, owner_id, start_time, end_time, status, priority,
		task_type, satellite_id, capability, assigned_to, metadata, created_at, updated_at
		FROM schedule_slots WHERE id = $1`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&slot.ID, &slot.StationID, &slot.OwnerID, &slot.StartTime, &slot.EndTime,
		&slot.Status, &slot.Priority, &taskType, &satelliteID, &slot.Capability,
		&assignedTo, &metaJSON, &slot.CreatedAt, &slot.UpdatedAt)
	if err != nil {
		return nil, err
	}
	slot.TaskType = taskType.String
	slot.SatelliteID = satelliteID.String
	slot.AssignedTo = assignedTo.String
	if metaJSON.Valid {
		json.Unmarshal([]byte(metaJSON.String), &slot.Metadata)
	}
	return slot, nil
}

func (r *slotRepo) List(ctx context.Context, filter ScheduleFilter) ([]*ScheduleSlot, error) {
	query := `SELECT id, station_id, owner_id, start_time, end_time, status, priority,
		task_type, satellite_id, capability, assigned_to, metadata, created_at, updated_at
		FROM schedule_slots WHERE 1=1`
	args := make([]interface{}, 0)
	argIdx := 1

	if filter.StationID != "" {
		query += fmt.Sprintf(" AND station_id = $%d", argIdx)
		args = append(args, filter.StationID)
		argIdx++
	}
	if filter.Status != nil {
		query += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, *filter.Status)
		argIdx++
	}
	if filter.FromTime != nil {
		query += fmt.Sprintf(" AND end_time >= $%d", argIdx)
		args = append(args, *filter.FromTime)
		argIdx++
	}
	if filter.ToTime != nil {
		query += fmt.Sprintf(" AND start_time <= $%d", argIdx)
		args = append(args, *filter.ToTime)
		argIdx++
	}
	if filter.OwnerID != "" {
		query += fmt.Sprintf(" AND owner_id = $%d", argIdx)
		args = append(args, filter.OwnerID)
		argIdx++
	}

	query += " ORDER BY start_time ASC"

	if filter.Limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argIdx)
		args = append(args, filter.Limit)
		argIdx++
	}
	if filter.Offset > 0 {
		query += fmt.Sprintf(" OFFSET $%d", argIdx)
		args = append(args, filter.Offset)
		argIdx++
	}

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var slots []*ScheduleSlot
	for rows.Next() {
		slot := &ScheduleSlot{}
		var taskType, satelliteID, assignedTo, metaJSON sql.NullString
		if err := rows.Scan(
			&slot.ID, &slot.StationID, &slot.OwnerID, &slot.StartTime, &slot.EndTime,
			&slot.Status, &slot.Priority, &taskType, &satelliteID, &slot.Capability,
			&assignedTo, &metaJSON, &slot.CreatedAt, &slot.UpdatedAt); err != nil {
			return nil, err
		}
		slot.TaskType = taskType.String
		slot.SatelliteID = satelliteID.String
		slot.AssignedTo = assignedTo.String
		if metaJSON.Valid {
			json.Unmarshal([]byte(metaJSON.String), &slot.Metadata)
		}
		slots = append(slots, slot)
	}
	return slots, rows.Err()
}

func (r *slotRepo) Update(ctx context.Context, slot *ScheduleSlot) error {
	metaJSON, _ := json.Marshal(slot.Metadata)
	query := `UPDATE schedule_slots SET station_id=$1, start_time=$2, end_time=$3,
		status=$4, priority=$5, task_type=$6, satellite_id=$7, capability=$8,
		assigned_to=$9, metadata=$10, updated_at=$11 WHERE id=$12`
	result, err := r.db.ExecContext(ctx, query,
		slot.StationID, slot.StartTime, slot.EndTime, slot.Status, slot.Priority,
		nullIfEmpty(slot.TaskType), nullIfEmpty(slot.SatelliteID), slot.Capability,
		nullIfEmpty(slot.AssignedTo), string(metaJSON), slot.UpdatedAt, slot.ID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *slotRepo) Delete(ctx context.Context, id string) error {
	result, err := r.db.ExecContext(ctx, "DELETE FROM schedule_slots WHERE id=$1", id)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func NewAssignmentRepository(db *sql.DB) AssignmentRepository {
	return &assignRepo{db: db}
}

type assignRepo struct {
	db *sql.DB
}

func (r *assignRepo) Create(ctx context.Context, a *Assignment) error {
	query := `INSERT INTO assignments (
		id, slot_id, user_id, station_id, satellite_id, start_time, end_time,
		status, priority, task_type, created_at
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`
	_, err := r.db.ExecContext(ctx, query,
		a.ID, a.SlotID, a.UserID, a.StationID, nullIfEmpty(a.SatelliteID),
		a.StartTime, a.EndTime, a.Status, a.Priority, nullIfEmpty(a.TaskType), a.CreatedAt)
	return err
}

func (r *assignRepo) GetByID(ctx context.Context, id string) (*Assignment, error) {
	a := &Assignment{}
	var satelliteID, taskType sql.NullString
	query := `SELECT id, slot_id, user_id, station_id, satellite_id, start_time, end_time,
		status, priority, task_type, created_at FROM assignments WHERE id=$1`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&a.ID, &a.SlotID, &a.UserID, &a.StationID, &satelliteID,
		&a.StartTime, &a.EndTime, &a.Status, &a.Priority, &taskType, &a.CreatedAt)
	if err != nil {
		return nil, err
	}
	a.SatelliteID = satelliteID.String
	a.TaskType = taskType.String
	return a, nil
}

func (r *assignRepo) ListByUser(ctx context.Context, userID string) ([]*Assignment, error) {
	query := `SELECT id, slot_id, user_id, station_id, satellite_id, start_time, end_time,
		status, priority, task_type, created_at FROM assignments WHERE user_id=$1
		ORDER BY start_time DESC`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assignments []*Assignment
	for rows.Next() {
		a := &Assignment{}
		var satelliteID, taskType sql.NullString
		if err := rows.Scan(
			&a.ID, &a.SlotID, &a.UserID, &a.StationID, &satelliteID,
			&a.StartTime, &a.EndTime, &a.Status, &a.Priority, &taskType, &a.CreatedAt); err != nil {
			return nil, err
		}
		a.SatelliteID = satelliteID.String
		a.TaskType = taskType.String
		assignments = append(assignments, a)
	}
	return assignments, rows.Err()
}

func (r *assignRepo) Update(ctx context.Context, a *Assignment) error {
	query := `UPDATE assignments SET status=$1, priority=$2 WHERE id=$3`
	result, err := r.db.ExecContext(ctx, query, a.Status, a.Priority, a.ID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *assignRepo) Delete(ctx context.Context, id string) error {
	result, err := r.db.ExecContext(ctx, "DELETE FROM assignments WHERE id=$1", id)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
