package stations

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
)

type Service interface {
	Register(ctx context.Context, input RegisterStationInput, ownerID string) (*Station, error)
	Get(ctx context.Context, id string) (*Station, error)
	List(ctx context.Context, filter StationFilter) ([]*Station, error)
	Update(ctx context.Context, id string, input UpdateStationInput) (*Station, error)
	Delete(ctx context.Context, id string) error
	UpdateStatus(ctx context.Context, id string, status StationStatus) error
	GetByOwner(ctx context.Context, ownerID string) ([]*Station, error)
}

type service struct {
	repo Repository
}

func NewService(repo Repository) Service {
	return &service{repo: repo}
}

func (s *service) Register(ctx context.Context, input RegisterStationInput, ownerID string) (*Station, error) {
	station := &Station{
		ID:              uuid.New().String(),
		OwnerID:         ownerID,
		Name:            input.Name,
		Location:        input.Location,
		Capabilities:    input.Capabilities,
		Status:          StationStatusOffline,
		IsVerified:      false,
		HardwareVersion: input.HardwareVersion,
		SoftwareVersion: input.SoftwareVersion,
		PublicKey:       input.PublicKey,
		Metadata:        input.Metadata,
		CreatedAt:       time.Now().UTC(),
		UpdatedAt:       time.Now().UTC(),
	}

	if err := s.repo.Create(ctx, station); err != nil {
		return nil, fmt.Errorf("registering station: %w", err)
	}

	return station, nil
}

func (s *service) Get(ctx context.Context, id string) (*Station, error) {
	station, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting station: %w", err)
	}
	return station, nil
}

func (s *service) List(ctx context.Context, filter StationFilter) ([]*Station, error) {
	if filter.Limit <= 0 || filter.Limit > 1000 {
		filter.Limit = 100
	}
	stations, err := s.repo.List(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("listing stations: %w", err)
	}
	return stations, nil
}

func (s *service) Update(ctx context.Context, id string, input UpdateStationInput) (*Station, error) {
	station, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting station for update: %w", err)
	}

	if input.Name != nil {
		station.Name = *input.Name
	}
	if input.Location != nil {
		station.Location = *input.Location
	}
	if input.Capabilities != nil {
		station.Capabilities = input.Capabilities
	}
	if input.Status != nil {
		station.Status = *input.Status
	}
	if input.HardwareVersion != nil {
		station.HardwareVersion = *input.HardwareVersion
	}
	if input.SoftwareVersion != nil {
		station.SoftwareVersion = *input.SoftwareVersion
	}
	if input.Metadata != nil {
		station.Metadata = *input.Metadata
	}

	if err := s.repo.Update(ctx, station); err != nil {
		return nil, fmt.Errorf("updating station: %w", err)
	}

	return station, nil
}

func (s *service) Delete(ctx context.Context, id string) error {
	if err := s.repo.Delete(ctx, id); err != nil {
		return fmt.Errorf("deleting station: %w", err)
	}
	return nil
}

func (s *service) UpdateStatus(ctx context.Context, id string, status StationStatus) error {
	if err := s.repo.UpdateStatus(ctx, id, status); err != nil {
		return fmt.Errorf("updating station status: %w", err)
	}
	return nil
}

func (s *service) GetByOwner(ctx context.Context, ownerID string) ([]*Station, error) {
	stations, err := s.repo.ListByOwner(ctx, ownerID)
	if err != nil {
		return nil, fmt.Errorf("getting stations by owner: %w", err)
	}
	return stations, nil
}
