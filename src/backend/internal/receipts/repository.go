package receipts

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

type Repository interface {
	Create(ctx context.Context, r *Receipt) error
	GetByID(ctx context.Context, id string) (*Receipt, error)
	List(ctx context.Context, filter ReceiptFilter) ([]*Receipt, error)
	Update(ctx context.Context, r *Receipt) error
	Delete(ctx context.Context, id string) error
	GetLastByStation(ctx context.Context, stationID string) (*Receipt, error)
	GetByStationAndSchedule(ctx context.Context, stationID, scheduleID string) (*Receipt, error)
	Count(ctx context.Context, filter ReceiptFilter) (int, error)
	GetChain(ctx context.Context, stationID string, limit int) ([]*Receipt, error)
}

type repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, rcpt *Receipt) error {
	proofJSON, err := json.Marshal(rcpt.Proof)
	if err != nil {
		return fmt.Errorf("marshaling proof: %w", err)
	}
	metaJSON, err := json.Marshal(rcpt.Metadata)
	if err != nil {
		return fmt.Errorf("marshaling metadata: %w", err)
	}

	query := `INSERT INTO receipts (
		id, station_id, schedule_id, task_id, signal_id, status,
		proof, prev_receipt_id, chain_position, merkle_root, metadata,
		created_at, verified_at
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`

	_, err = r.db.ExecContext(ctx, query,
		rcpt.ID, rcpt.StationID, nullIfEmpty(rcpt.ScheduleID),
		nullIfEmpty(rcpt.TaskID), nullIfEmpty(rcpt.SignalID),
		rcpt.Status, string(proofJSON), nullIfEmpty(rcpt.PrevReceiptID),
		rcpt.ChainPosition, nullIfEmpty(rcpt.MerkleRoot),
		string(metaJSON), rcpt.CreatedAt, rcpt.VerifiedAt,
	)
	if err != nil {
		return fmt.Errorf("inserting receipt: %w", err)
	}
	return nil
}

func (r *repository) GetByID(ctx context.Context, id string) (*Receipt, error) {
	query := `SELECT id, station_id, schedule_id, task_id, signal_id, status,
		proof, prev_receipt_id, chain_position, merkle_root, metadata,
		created_at, verified_at
		FROM receipts WHERE id = $1`

	rcpt := &Receipt{}
	var scheduleID, taskID, signalID, prevReceiptID, merkleRoot, metaJSON sql.NullString
	var proofJSON string

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&rcpt.ID, &rcpt.StationID, &scheduleID, &taskID, &signalID,
		&rcpt.Status, &proofJSON, &prevReceiptID, &rcpt.ChainPosition,
		&merkleRoot, &metaJSON, &rcpt.CreatedAt, &rcpt.VerifiedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("receipt %s: %w", id, err)
		}
		return nil, fmt.Errorf("querying receipt %s: %w", id, err)
	}

	json.Unmarshal([]byte(proofJSON), &rcpt.Proof)
	if metaJSON.Valid {
		json.Unmarshal([]byte(metaJSON.String), &rcpt.Metadata)
	}
	rcpt.ScheduleID = scheduleID.String
	rcpt.TaskID = taskID.String
	rcpt.SignalID = signalID.String
	rcpt.PrevReceiptID = prevReceiptID.String
	rcpt.MerkleRoot = merkleRoot.String

	return rcpt, nil
}

func (r *repository) List(ctx context.Context, filter ReceiptFilter) ([]*Receipt, error) {
	query := `SELECT id, station_id, schedule_id, task_id, signal_id, status,
		proof, prev_receipt_id, chain_position, merkle_root, metadata,
		created_at, verified_at
		FROM receipts WHERE 1=1`

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
	if filter.FromDate != nil {
		query += fmt.Sprintf(" AND created_at >= $%d", argIdx)
		args = append(args, *filter.FromDate)
		argIdx++
	}
	if filter.ToDate != nil {
		query += fmt.Sprintf(" AND created_at <= $%d", argIdx)
		args = append(args, *filter.ToDate)
		argIdx++
	}

	query += " ORDER BY chain_position DESC"

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
		return nil, fmt.Errorf("listing receipts: %w", err)
	}
	defer rows.Close()

	var receipts []*Receipt
	for rows.Next() {
		rcpt := &Receipt{}
		var scheduleID, taskID, signalID, prevReceiptID, merkleRoot, metaJSON sql.NullString
		var proofJSON string

		if err := rows.Scan(
			&rcpt.ID, &rcpt.StationID, &scheduleID, &taskID, &signalID,
			&rcpt.Status, &proofJSON, &prevReceiptID, &rcpt.ChainPosition,
			&merkleRoot, &metaJSON, &rcpt.CreatedAt, &rcpt.VerifiedAt,
		); err != nil {
			return nil, fmt.Errorf("scanning receipt: %w", err)
		}
		json.Unmarshal([]byte(proofJSON), &rcpt.Proof)
		if metaJSON.Valid {
			json.Unmarshal([]byte(metaJSON.String), &rcpt.Metadata)
		}
		rcpt.ScheduleID = scheduleID.String
		rcpt.TaskID = taskID.String
		rcpt.SignalID = signalID.String
		rcpt.PrevReceiptID = prevReceiptID.String
		rcpt.MerkleRoot = merkleRoot.String

		receipts = append(receipts, rcpt)
	}

	return receipts, rows.Err()
}

func (r *repository) Update(ctx context.Context, rcpt *Receipt) error {
	proofJSON, err := json.Marshal(rcpt.Proof)
	if err != nil {
		return fmt.Errorf("marshaling proof: %w", err)
	}
	metaJSON, err := json.Marshal(rcpt.Metadata)
	if err != nil {
		return fmt.Errorf("marshaling metadata: %w", err)
	}

	query := `UPDATE receipts SET
		status = $1, proof = $2, merkle_root = $3, metadata = $4, verified_at = $5
		WHERE id = $6`

	result, err := r.db.ExecContext(ctx, query,
		rcpt.Status, string(proofJSON), nullIfEmpty(rcpt.MerkleRoot),
		string(metaJSON), rcpt.VerifiedAt, rcpt.ID,
	)
	if err != nil {
		return fmt.Errorf("updating receipt %s: %w", rcpt.ID, err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("receipt %s: %w", rcpt.ID, sql.ErrNoRows)
	}
	return nil
}

func (r *repository) Delete(ctx context.Context, id string) error {
	result, err := r.db.ExecContext(ctx, "DELETE FROM receipts WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("deleting receipt %s: %w", id, err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("receipt %s: %w", id, sql.ErrNoRows)
	}
	return nil
}

func (r *repository) GetLastByStation(ctx context.Context, stationID string) (*Receipt, error) {
	query := `SELECT id, station_id, schedule_id, task_id, signal_id, status,
		proof, prev_receipt_id, chain_position, merkle_root, metadata,
		created_at, verified_at
		FROM receipts WHERE station_id = $1
		ORDER BY chain_position DESC LIMIT 1`

	rcpt := &Receipt{}
	var scheduleID, taskID, signalID, prevReceiptID, merkleRoot, metaJSON sql.NullString
	var proofJSON string

	err := r.db.QueryRowContext(ctx, query, stationID).Scan(
		&rcpt.ID, &rcpt.StationID, &scheduleID, &taskID, &signalID,
		&rcpt.Status, &proofJSON, &prevReceiptID, &rcpt.ChainPosition,
		&merkleRoot, &metaJSON, &rcpt.CreatedAt, &rcpt.VerifiedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("querying last receipt for station %s: %w", stationID, err)
	}

	json.Unmarshal([]byte(proofJSON), &rcpt.Proof)
	if metaJSON.Valid {
		json.Unmarshal([]byte(metaJSON.String), &rcpt.Metadata)
	}
	rcpt.ScheduleID = scheduleID.String
	rcpt.TaskID = taskID.String
	rcpt.SignalID = signalID.String
	rcpt.PrevReceiptID = prevReceiptID.String
	rcpt.MerkleRoot = merkleRoot.String

	return rcpt, nil
}

func (r *repository) GetByStationAndSchedule(ctx context.Context, stationID, scheduleID string) (*Receipt, error) {
	query := `SELECT id, station_id, schedule_id, task_id, signal_id, status,
		proof, prev_receipt_id, chain_position, merkle_root, metadata,
		created_at, verified_at
		FROM receipts WHERE station_id = $1 AND schedule_id = $2 LIMIT 1`

	rcpt := &Receipt{}
	var proofJSON string
	var scheduleID2, taskID, signalID, prevReceiptID, merkleRoot, metaJSON sql.NullString

	err := r.db.QueryRowContext(ctx, query, stationID, scheduleID).Scan(
		&rcpt.ID, &rcpt.StationID, &scheduleID2, &taskID, &signalID,
		&rcpt.Status, &proofJSON, &prevReceiptID, &rcpt.ChainPosition,
		&merkleRoot, &metaJSON, &rcpt.CreatedAt, &rcpt.VerifiedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("querying receipt by station and schedule: %w", err)
	}

	json.Unmarshal([]byte(proofJSON), &rcpt.Proof)
	if metaJSON.Valid {
		json.Unmarshal([]byte(metaJSON.String), &rcpt.Metadata)
	}
	rcpt.ScheduleID = scheduleID2.String
	rcpt.TaskID = taskID.String
	rcpt.SignalID = signalID.String
	rcpt.PrevReceiptID = prevReceiptID.String
	rcpt.MerkleRoot = merkleRoot.String

	return rcpt, nil
}

func (r *repository) Count(ctx context.Context, filter ReceiptFilter) (int, error) {
	query := "SELECT COUNT(*) FROM receipts WHERE 1=1"
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

	var count int
	err := r.db.QueryRowContext(ctx, query, args...).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("counting receipts: %w", err)
	}
	return count, nil
}

func (r *repository) GetChain(ctx context.Context, stationID string, limit int) ([]*Receipt, error) {
	return r.List(ctx, ReceiptFilter{
		StationID: stationID,
		Limit:     limit,
	})
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
