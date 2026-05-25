package stations

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

type Repository interface {
	Create(ctx context.Context, s *Station) error
	GetByID(ctx context.Context, id string) (*Station, error)
	List(ctx context.Context, filter StationFilter) ([]*Station, error)
	Update(ctx context.Context, s *Station) error
	Delete(ctx context.Context, id string) error
	UpdateStatus(ctx context.Context, id string, status StationStatus) error
	ListByOwner(ctx context.Context, ownerID string) ([]*Station, error)
}

type repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, s *Station) error {
	capJSON, err := json.Marshal(s.Capabilities)
	if err != nil {
		return fmt.Errorf("marshaling capabilities: %w", err)
	}
	metaJSON, err := json.Marshal(s.Metadata)
	if err != nil {
		return fmt.Errorf("marshaling metadata: %w", err)
	}
	locJSON, err := json.Marshal(s.Location)
	if err != nil {
		return fmt.Errorf("marshaling location: %w", err)
	}

	query := `INSERT INTO stations (
		id, owner_id, name, location, capabilities, status, is_verified,
		hardware_version, software_version, public_key, metadata,
		created_at, updated_at, last_contact_at
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`

	_, err = r.db.ExecContext(ctx, query,
		s.ID, s.OwnerID, s.Name, string(locJSON), string(capJSON),
		s.Status, s.IsVerified, s.HardwareVersion, s.SoftwareVersion,
		s.PublicKey, string(metaJSON), s.CreatedAt, s.UpdatedAt, s.LastContactAt,
	)
	if err != nil {
		return fmt.Errorf("inserting station: %w", err)
	}
	return nil
}

func (r *repository) GetByID(ctx context.Context, id string) (*Station, error) {
	query := `SELECT id, owner_id, name, location, capabilities, status, is_verified,
		hardware_version, software_version, public_key, metadata,
		created_at, updated_at, last_contact_at
		FROM stations WHERE id = $1`

	s := &Station{}
	var locJSON, capJSON, metaJSON sql.NullString
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&s.ID, &s.OwnerID, &s.Name, &locJSON, &capJSON, &s.Status, &s.IsVerified,
		&s.HardwareVersion, &s.SoftwareVersion, &s.PublicKey, &metaJSON,
		&s.CreatedAt, &s.UpdatedAt, &s.LastContactAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("station %s: %w", id, err)
		}
		return nil, fmt.Errorf("querying station %s: %w", id, err)
	}

	if locJSON.Valid {
		if err := json.Unmarshal([]byte(locJSON.String), &s.Location); err != nil {
			return nil, fmt.Errorf("unmarshaling location: %w", err)
		}
	}
	if capJSON.Valid {
		if err := json.Unmarshal([]byte(capJSON.String), &s.Capabilities); err != nil {
			return nil, fmt.Errorf("unmarshaling capabilities: %w", err)
		}
	}
	if metaJSON.Valid {
		if err := json.Unmarshal([]byte(metaJSON.String), &s.Metadata); err != nil {
			return nil, fmt.Errorf("unmarshaling metadata: %w", err)
		}
	}

	return s, nil
}

func (r *repository) List(ctx context.Context, filter StationFilter) ([]*Station, error) {
	query := `SELECT id, owner_id, name, location, capabilities, status, is_verified,
		hardware_version, software_version, public_key, metadata,
		created_at, updated_at, last_contact_at
		FROM stations WHERE 1=1`

	args := make([]interface{}, 0)
	argIdx := 1

	if filter.Status != nil {
		query += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, *filter.Status)
		argIdx++
	}
	if filter.OwnerID != "" {
		query += fmt.Sprintf(" AND owner_id = $%d", argIdx)
		args = append(args, filter.OwnerID)
		argIdx++
	}
	if filter.Verified != nil {
		query += fmt.Sprintf(" AND is_verified = $%d", argIdx)
		args = append(args, *filter.Verified)
		argIdx++
	}

	query += " ORDER BY created_at DESC"

	if filter.Limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argIdx)
		args = append(args, filter.Limit)
		argIdx++
	} else {
		query += " LIMIT 100"
	}
	if filter.Offset > 0 {
		query += fmt.Sprintf(" OFFSET $%d", argIdx)
		args = append(args, filter.Offset)
		argIdx++
	}

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("listing stations: %w", err)
	}
	defer rows.Close()

	var stations []*Station
	for rows.Next() {
		s := &Station{}
		var locJSON, capJSON, metaJSON sql.NullString
		if err := rows.Scan(
			&s.ID, &s.OwnerID, &s.Name, &locJSON, &capJSON, &s.Status, &s.IsVerified,
			&s.HardwareVersion, &s.SoftwareVersion, &s.PublicKey, &metaJSON,
			&s.CreatedAt, &s.UpdatedAt, &s.LastContactAt,
		); err != nil {
			return nil, fmt.Errorf("scanning station row: %w", err)
		}
		if locJSON.Valid {
			json.Unmarshal([]byte(locJSON.String), &s.Location)
		}
		if capJSON.Valid {
			json.Unmarshal([]byte(capJSON.String), &s.Capabilities)
		}
		if metaJSON.Valid {
			json.Unmarshal([]byte(metaJSON.String), &s.Metadata)
		}
		stations = append(stations, s)
	}

	return stations, rows.Err()
}

func (r *repository) Update(ctx context.Context, s *Station) error {
	capJSON, err := json.Marshal(s.Capabilities)
	if err != nil {
		return fmt.Errorf("marshaling capabilities: %w", err)
	}
	metaJSON, err := json.Marshal(s.Metadata)
	if err != nil {
		return fmt.Errorf("marshaling metadata: %w", err)
	}
	locJSON, err := json.Marshal(s.Location)
	if err != nil {
		return fmt.Errorf("marshaling location: %w", err)
	}

	s.UpdatedAt = time.Now()

	query := `UPDATE stations SET
		name = $1, location = $2, capabilities = $3, status = $4,
		is_verified = $5, hardware_version = $6, software_version = $7,
		public_key = $8, metadata = $9, updated_at = $10, last_contact_at = $11
		WHERE id = $12`

	result, err := r.db.ExecContext(ctx, query,
		s.Name, string(locJSON), string(capJSON), s.Status,
		s.IsVerified, s.HardwareVersion, s.SoftwareVersion,
		s.PublicKey, string(metaJSON), s.UpdatedAt, s.LastContactAt, s.ID,
	)
	if err != nil {
		return fmt.Errorf("updating station %s: %w", s.ID, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("station %s: %w", s.ID, sql.ErrNoRows)
	}
	return nil
}

func (r *repository) Delete(ctx context.Context, id string) error {
	result, err := r.db.ExecContext(ctx, "DELETE FROM stations WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("deleting station %s: %w", id, err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("station %s: %w", id, sql.ErrNoRows)
	}
	return nil
}

func (r *repository) UpdateStatus(ctx context.Context, id string, status StationStatus) error {
	query := "UPDATE stations SET status = $1, updated_at = $2, last_contact_at = $3 WHERE id = $4"
	result, err := r.db.ExecContext(ctx, query, status, time.Now(), time.Now(), id)
	if err != nil {
		return fmt.Errorf("updating station %s status: %w", id, err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("station %s: %w", id, sql.ErrNoRows)
	}
	return nil
}

func (r *repository) ListByOwner(ctx context.Context, ownerID string) ([]*Station, error) {
	return r.List(ctx, StationFilter{OwnerID: ownerID})
}
