package proto

import (
	"github.com/quantumworld-dpdns-io/dgsn/internal/stations"
)

type StationProto struct {
	ID              string             `protobuf:"bytes,1,opt,name=id,proto3" json:"id,omitempty"`
	OwnerID         string             `protobuf:"bytes,2,opt,name=owner_id,json=ownerId,proto3" json:"owner_id,omitempty"`
	Name            string             `protobuf:"bytes,3,opt,name=name,proto3" json:"name,omitempty"`
	Location        *LocationProto     `protobuf:"bytes,4,opt,name=location,proto3" json:"location,omitempty"`
	Capabilities    []*CapabilityProto `protobuf:"bytes,5,rep,name=capabilities,proto3" json:"capabilities,omitempty"`
	Status          string             `protobuf:"bytes,6,opt,name=status,proto3" json:"status,omitempty"`
	IsVerified      bool               `protobuf:"varint,7,opt,name=is_verified,json=isVerified,proto3" json:"is_verified,omitempty"`
	HardwareVersion string             `protobuf:"bytes,8,opt,name=hardware_version,json=hardwareVersion,proto3" json:"hardware_version,omitempty"`
	SoftwareVersion string             `protobuf:"bytes,9,opt,name=software_version,json=softwareVersion,proto3" json:"software_version,omitempty"`
	PublicKey       string             `protobuf:"bytes,10,opt,name=public_key,json=publicKey,proto3" json:"public_key,omitempty"`
	Metadata        map[string]string  `protobuf:"bytes,11,rep,name=metadata,proto3" json:"metadata,omitempty" protobuf_key:"bytes,1,opt,name=key" protobuf_val:"bytes,2,opt,name=value"`
	CreatedAt       int64              `protobuf:"varint,12,opt,name=created_at,json=createdAt,proto3" json:"created_at,omitempty"`
	UpdatedAt       int64              `protobuf:"varint,13,opt,name=updated_at,json=updatedAt,proto3" json:"updated_at,omitempty"`
	LastContactAt   *int64             `protobuf:"varint,14,opt,name=last_contact_at,json=lastContactAt,proto3" json:"last_contact_at,omitempty"`
}

type LocationProto struct {
	Latitude  float64 `protobuf:"fixed64,1,opt,name=latitude,proto3" json:"latitude,omitempty"`
	Longitude float64 `protobuf:"fixed64,2,opt,name=longitude,proto3" json:"longitude,omitempty"`
	Altitude  float64 `protobuf:"fixed64,3,opt,name=altitude,proto3" json:"altitude,omitempty"`
	Name      string  `protobuf:"bytes,4,opt,name=name,proto3" json:"name,omitempty"`
}

type CapabilityProto struct {
	Type         string  `protobuf:"bytes,1,opt,name=type,proto3" json:"type,omitempty"`
	Frequency    float64 `protobuf:"fixed64,2,opt,name=frequency,proto3" json:"frequency,omitempty"`
	Bandwidth    float64 `protobuf:"fixed64,3,opt,name=bandwidth,proto3" json:"bandwidth,omitempty"`
	DataRate     float64 `protobuf:"fixed64,4,opt,name=data_rate,json=dataRate,proto3" json:"data_rate,omitempty"`
	Polarization string  `protobuf:"bytes,5,opt,name=polarization,proto3" json:"polarization,omitempty"`
	MinElevation float64 `protobuf:"fixed64,6,opt,name=min_elevation,json=minElevation,proto3" json:"min_elevation,omitempty"`
	Active       bool    `protobuf:"varint,7,opt,name=active,proto3" json:"active,omitempty"`
}

func ToProtoStation(s *stations.Station) *StationProto {
	if s == nil {
		return nil
	}

	proto := &StationProto{
		ID:              s.ID,
		OwnerID:         s.OwnerID,
		Name:            s.Name,
		Status:          string(s.Status),
		IsVerified:      s.IsVerified,
		HardwareVersion: s.HardwareVersion,
		SoftwareVersion: s.SoftwareVersion,
		PublicKey:       s.PublicKey,
		CreatedAt:       s.CreatedAt.UnixNano(),
		UpdatedAt:       s.UpdatedAt.UnixNano(),
	}

	proto.Location = ToProtoLocation(&s.Location)

	proto.Capabilities = make([]*CapabilityProto, len(s.Capabilities))
	for i, c := range s.Capabilities {
		proto.Capabilities[i] = ToProtoCapability(&c)
	}

	if len(s.Metadata) > 0 {
		proto.Metadata = make(map[string]string)
		for k, v := range s.Metadata {
			proto.Metadata[k] = v
		}
	}

	if s.LastContactAt != nil {
		ts := s.LastContactAt.UnixNano()
		proto.LastContactAt = &ts
	}

	return proto
}

func ToProtoLocation(l *stations.Location) *LocationProto {
	if l == nil {
		return nil
	}
	return &LocationProto{
		Latitude:  l.Latitude,
		Longitude: l.Longitude,
		Altitude:  l.Altitude,
		Name:      l.Name,
	}
}

func ToProtoCapability(c *stations.StationCapability) *CapabilityProto {
	if c == nil {
		return nil
	}
	return &CapabilityProto{
		Type:         string(c.Type),
		Frequency:    c.Frequency,
		Bandwidth:    c.Bandwidth,
		DataRate:     c.DataRate,
		Polarization: c.Polarization,
		MinElevation: c.MinElevation,
		Active:       c.Active,
	}
}

func FromProtoStation(p *StationProto) *stations.Station {
	if p == nil {
		return nil
	}

	s := &stations.Station{
		ID:              p.ID,
		OwnerID:         p.OwnerID,
		Name:            p.Name,
		Status:          stations.StationStatus(p.Status),
		IsVerified:      p.IsVerified,
		HardwareVersion: p.HardwareVersion,
		SoftwareVersion: p.SoftwareVersion,
		PublicKey:       p.PublicKey,
	}

	if p.Location != nil {
		s.Location = *FromProtoLocation(p.Location)
	}

	if len(p.Capabilities) > 0 {
		s.Capabilities = make([]stations.StationCapability, len(p.Capabilities))
		for i, c := range p.Capabilities {
			s.Capabilities[i] = *FromProtoCapability(c)
		}
	}

	if len(p.Metadata) > 0 {
		s.Metadata = make(map[string]string)
		for k, v := range p.Metadata {
			s.Metadata[k] = v
		}
	}

	return s
}

func FromProtoLocation(p *LocationProto) *stations.Location {
	if p == nil {
		return nil
	}
	return &stations.Location{
		Latitude:  p.Latitude,
		Longitude: p.Longitude,
		Altitude:  p.Altitude,
		Name:      p.Name,
	}
}

func FromProtoCapability(p *CapabilityProto) *stations.StationCapability {
	if p == nil {
		return nil
	}
	return &stations.StationCapability{
		Type:         stations.CapabilityType(p.Type),
		Frequency:    p.Frequency,
		Bandwidth:    p.Bandwidth,
		DataRate:     p.DataRate,
		Polarization: p.Polarization,
		MinElevation: p.MinElevation,
		Active:       p.Active,
	}
}

func ToProtoStationList(stations []*stations.Station) []*StationProto {
	if stations == nil {
		return nil
	}
	protoList := make([]*StationProto, len(stations))
	for i, s := range stations {
		protoList[i] = ToProtoStation(s)
	}
	return protoList
}

func FromProtoStationList(protoList []*StationProto) []*stations.Station {
	if protoList == nil {
		return nil
	}
	stationsList := make([]*stations.Station, len(protoList))
	for i, p := range protoList {
		stationsList[i] = FromProtoStation(p)
	}
	return stationsList
}

type RegisterStationRequestProto struct {
	Name            string             `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Location        *LocationProto     `protobuf:"bytes,2,opt,name=location,proto3" json:"location,omitempty"`
	Capabilities    []*CapabilityProto `protobuf:"bytes,3,rep,name=capabilities,proto3" json:"capabilities,omitempty"`
	HardwareVersion string             `protobuf:"bytes,4,opt,name=hardware_version,json=hardwareVersion,proto3" json:"hardware_version,omitempty"`
	SoftwareVersion string             `protobuf:"bytes,5,opt,name=software_version,json=softwareVersion,proto3" json:"software_version,omitempty"`
	PublicKey       string             `protobuf:"bytes,6,opt,name=public_key,json=publicKey,proto3" json:"public_key,omitempty"`
	Metadata        map[string]string  `protobuf:"bytes,7,rep,name=metadata,proto3" json:"metadata,omitempty"`
}

func FromProtoRegisterRequest(p *RegisterStationRequestProto) *stations.RegisterStationInput {
	if p == nil {
		return nil
	}

	input := &stations.RegisterStationInput{
		Name:            p.Name,
		HardwareVersion: p.HardwareVersion,
		SoftwareVersion: p.SoftwareVersion,
		PublicKey:       p.PublicKey,
	}

	if p.Location != nil {
		input.Location = *FromProtoLocation(p.Location)
	}

	if len(p.Capabilities) > 0 {
		input.Capabilities = make([]stations.StationCapability, len(p.Capabilities))
		for i, c := range p.Capabilities {
			input.Capabilities[i] = *FromProtoCapability(c)
		}
	}

	if len(p.Metadata) > 0 {
		input.Metadata = make(map[string]string)
		for k, v := range p.Metadata {
			input.Metadata[k] = v
		}
	}

	return input
}

func ToProtoRegisterRequest(input *stations.RegisterStationInput) *RegisterStationRequestProto {
	if input == nil {
		return nil
	}

	p := &RegisterStationRequestProto{
		Name:            input.Name,
		HardwareVersion: input.HardwareVersion,
		SoftwareVersion: input.SoftwareVersion,
		PublicKey:       input.PublicKey,
	}

	p.Location = ToProtoLocation(&input.Location)

	if len(input.Capabilities) > 0 {
		p.Capabilities = make([]*CapabilityProto, len(input.Capabilities))
		for i, c := range input.Capabilities {
			p.Capabilities[i] = ToProtoCapability(&c)
		}
	}

	if len(input.Metadata) > 0 {
		p.Metadata = make(map[string]string)
		for k, v := range input.Metadata {
			p.Metadata[k] = v
		}
	}

	return p
}
