package proto

import (
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/internal/receipts"
)

type ReceiptProto struct {
	ID            string           `protobuf:"bytes,1,opt,name=id,proto3" json:"id,omitempty"`
	StationID     string           `protobuf:"bytes,2,opt,name=station_id,json=stationId,proto3" json:"station_id,omitempty"`
	ScheduleID    string           `protobuf:"bytes,3,opt,name=schedule_id,json=scheduleId,proto3" json:"schedule_id,omitempty"`
	TaskID        string           `protobuf:"bytes,4,opt,name=task_id,json=taskId,proto3" json:"task_id,omitempty"`
	SignalID      string           `protobuf:"bytes,5,opt,name=signal_id,json=signalId,proto3" json:"signal_id,omitempty"`
	Status        string           `protobuf:"bytes,6,opt,name=status,proto3" json:"status,omitempty"`
	Proof         *ProofDataProto  `protobuf:"bytes,7,opt,name=proof,proto3" json:"proof,omitempty"`
	PrevReceiptID string           `protobuf:"bytes,8,opt,name=prev_receipt_id,json=prevReceiptId,proto3" json:"prev_receipt_id,omitempty"`
	ChainPosition int64            `protobuf:"varint,9,opt,name=chain_position,json=chainPosition,proto3" json:"chain_position,omitempty"`
	MerkleRoot    string           `protobuf:"bytes,10,opt,name=merkle_root,json=merkleRoot,proto3" json:"merkle_root,omitempty"`
	Metadata      map[string]string `protobuf:"bytes,11,rep,name=metadata,proto3" json:"metadata,omitempty"`
	CreatedAt     int64            `protobuf:"varint,12,opt,name=created_at,json=createdAt,proto3" json:"created_at,omitempty"`
	VerifiedAt    *int64           `protobuf:"varint,13,opt,name=verified_at,json=verifiedAt,proto3" json:"verified_at,omitempty"`
}

type ProofDataProto struct {
	Type      string `protobuf:"bytes,1,opt,name=type,proto3" json:"type,omitempty"`
	Algorithm string `protobuf:"bytes,2,opt,name=algorithm,proto3" json:"algorithm,omitempty"`
	Value     string `protobuf:"bytes,3,opt,name=value,proto3" json:"value,omitempty"`
	PublicKey string `protobuf:"bytes,4,opt,name=public_key,json=publicKey,proto3" json:"public_key,omitempty"`
	Nonce     string `protobuf:"bytes,5,opt,name=nonce,proto3" json:"nonce,omitempty"`
	Signature string `protobuf:"bytes,6,opt,name=signature,proto3" json:"signature,omitempty"`
	Hash      string `protobuf:"bytes,7,opt,name=hash,proto3" json:"hash,omitempty"`
	PrevHash  string `protobuf:"bytes,8,opt,name=prev_hash,json=prevHash,proto3" json:"prev_hash,omitempty"`
}

type VerificationResultProto struct {
	IsValid      bool   `protobuf:"varint,1,opt,name=is_valid,json=isValid,proto3" json:"is_valid,omitempty"`
	ReceiptID    string `protobuf:"bytes,2,opt,name=receipt_id,json=receiptId,proto3" json:"receipt_id,omitempty"`
	VerifiedAt   int64  `protobuf:"varint,3,opt,name=verified_at,json=verifiedAt,proto3" json:"verified_at,omitempty"`
	ErrorMessage string `protobuf:"bytes,4,opt,name=error_message,json=errorMessage,proto3" json:"error_message,omitempty"`
	ChainStatus  string `protobuf:"bytes,5,opt,name=chain_status,json=chainStatus,proto3" json:"chain_status,omitempty"`
}

type CreateReceiptRequestProto struct {
	StationID  string           `protobuf:"bytes,1,opt,name=station_id,json=stationId,proto3" json:"station_id,omitempty"`
	ScheduleID string           `protobuf:"bytes,2,opt,name=schedule_id,json=scheduleId,proto3" json:"schedule_id,omitempty"`
	TaskID     string           `protobuf:"bytes,3,opt,name=task_id,json=taskId,proto3" json:"task_id,omitempty"`
	SignalID   string           `protobuf:"bytes,4,opt,name=signal_id,json=signalId,proto3" json:"signal_id,omitempty"`
	Proof      *ProofDataProto  `protobuf:"bytes,5,opt,name=proof,proto3" json:"proof,omitempty"`
	Metadata   map[string]string `protobuf:"bytes,6,rep,name=metadata,proto3" json:"metadata,omitempty"`
}

type VerifyReceiptRequestProto struct {
	ReceiptID   string `protobuf:"bytes,1,opt,name=receipt_id,json=receiptId,proto3" json:"receipt_id,omitempty"`
	StationID   string `protobuf:"bytes,2,opt,name=station_id,json=stationId,proto3" json:"station_id,omitempty"`
	ProofValue  string `protobuf:"bytes,3,opt,name=proof_value,json=proofValue,proto3" json:"proof_value,omitempty"`
	PublicKey   string `protobuf:"bytes,4,opt,name=public_key,json=publicKey,proto3" json:"public_key,omitempty"`
}

func ToProtoReceipt(r *receipts.Receipt) *ReceiptProto {
	if r == nil {
		return nil
	}

	proto := &ReceiptProto{
		ID:            r.ID,
		StationID:     r.StationID,
		ScheduleID:    r.ScheduleID,
		TaskID:        r.TaskID,
		SignalID:      r.SignalID,
		Status:        string(r.Status),
		PrevReceiptID: r.PrevReceiptID,
		ChainPosition: r.ChainPosition,
		MerkleRoot:    r.MerkleRoot,
		CreatedAt:     r.CreatedAt.UnixNano(),
	}

	proto.Proof = ToProtoProofData(&r.Proof)

	if len(r.Metadata) > 0 {
		proto.Metadata = make(map[string]string)
		for k, v := range r.Metadata {
			proto.Metadata[k] = v
		}
	}

	if r.VerifiedAt != nil {
		ts := r.VerifiedAt.UnixNano()
		proto.VerifiedAt = &ts
	}

	return proto
}

func ToProtoProofData(p *receipts.ProofData) *ProofDataProto {
	if p == nil {
		return nil
	}
	return &ProofDataProto{
		Type:      string(p.Type),
		Algorithm: p.Algorithm,
		Value:     p.Value,
		PublicKey: p.PublicKey,
		Nonce:     p.Nonce,
		Signature: p.Signature,
		Hash:      p.Hash,
		PrevHash:  p.PrevHash,
	}
}

func ToProtoVerificationResult(v *receipts.VerificationResult) *VerificationResultProto {
	if v == nil {
		return nil
	}

	proto := &VerificationResultProto{
		IsValid:      v.IsValid,
		ReceiptID:    v.ReceiptID,
		ErrorMessage: v.ErrorMessage,
		ChainStatus:  v.ChainStatus,
	}

	if !v.VerifiedAt.IsZero() {
		proto.VerifiedAt = v.VerifiedAt.UnixNano()
	}

	return proto
}

func FromProtoReceipt(p *ReceiptProto) *receipts.Receipt {
	if p == nil {
		return nil
	}

	r := &receipts.Receipt{
		ID:            p.ID,
		StationID:     p.StationID,
		ScheduleID:    p.ScheduleID,
		TaskID:        p.TaskID,
		SignalID:      p.SignalID,
		Status:        receipts.ReceiptStatus(p.Status),
		PrevReceiptID: p.PrevReceiptID,
		ChainPosition: p.ChainPosition,
		MerkleRoot:    p.MerkleRoot,
		CreatedAt:     time.Unix(0, p.CreatedAt).UTC(),
	}

	if p.Proof != nil {
		r.Proof = *FromProtoProofData(p.Proof)
	}

	if len(p.Metadata) > 0 {
		r.Metadata = make(map[string]string)
		for k, v := range p.Metadata {
			r.Metadata[k] = v
		}
	}

	if p.VerifiedAt != nil {
		ts := time.Unix(0, *p.VerifiedAt).UTC()
		r.VerifiedAt = &ts
	}

	return r
}

func FromProtoProofData(p *ProofDataProto) *receipts.ProofData {
	if p == nil {
		return nil
	}
	return &receipts.ProofData{
		Type:      receipts.ProofType(p.Type),
		Algorithm: p.Algorithm,
		Value:     p.Value,
		PublicKey: p.PublicKey,
		Nonce:     p.Nonce,
		Signature: p.Signature,
		Hash:      p.Hash,
		PrevHash:  p.PrevHash,
	}
}

func FromProtoVerificationResult(p *VerificationResultProto) *receipts.VerificationResult {
	if p == nil {
		return nil
	}

	v := &receipts.VerificationResult{
		IsValid:      p.IsValid,
		ReceiptID:    p.ReceiptID,
		ErrorMessage: p.ErrorMessage,
		ChainStatus:  p.ChainStatus,
	}

	if p.VerifiedAt > 0 {
		v.VerifiedAt = time.Unix(0, p.VerifiedAt).UTC()
	}

	return v
}

func FromProtoCreateReceiptRequest(p *CreateReceiptRequestProto) *receipts.CreateReceiptInput {
	if p == nil {
		return nil
	}

	input := &receipts.CreateReceiptInput{
		StationID:  p.StationID,
		ScheduleID: p.ScheduleID,
		TaskID:     p.TaskID,
		SignalID:   p.SignalID,
	}

	if p.Proof != nil {
		input.Proof = *FromProtoProofData(p.Proof)
	}

	if len(p.Metadata) > 0 {
		input.Metadata = make(map[string]string)
		for k, v := range p.Metadata {
			input.Metadata[k] = v
		}
	}

	return input
}

func ToProtoCreateReceiptRequest(input *receipts.CreateReceiptInput) *CreateReceiptRequestProto {
	if input == nil {
		return nil
	}

	p := &CreateReceiptRequestProto{
		StationID:  input.StationID,
		ScheduleID: input.ScheduleID,
		TaskID:     input.TaskID,
		SignalID:   input.SignalID,
	}

	p.Proof = ToProtoProofData(&input.Proof)

	if len(input.Metadata) > 0 {
		p.Metadata = make(map[string]string)
		for k, v := range input.Metadata {
			p.Metadata[k] = v
		}
	}

	return p
}

func FromProtoVerifyReceiptRequest(p *VerifyReceiptRequestProto) *receipts.VerifyReceiptInput {
	if p == nil {
		return nil
	}
	return &receipts.VerifyReceiptInput{
		ReceiptID:  p.ReceiptID,
		StationID:  p.StationID,
		ProofValue: p.ProofValue,
		PublicKey:  p.PublicKey,
	}
}

func ToProtoVerifyReceiptRequest(input *receipts.VerifyReceiptInput) *VerifyReceiptRequestProto {
	if input == nil {
		return nil
	}
	return &VerifyReceiptRequestProto{
		ReceiptID:  input.ReceiptID,
		StationID:  input.StationID,
		ProofValue: input.ProofValue,
		PublicKey:  input.PublicKey,
	}
}

func ToProtoReceiptList(receipts []*receipts.Receipt) []*ReceiptProto {
	if receipts == nil {
		return nil
	}
	protoList := make([]*ReceiptProto, len(receipts))
	for i, r := range receipts {
		protoList[i] = ToProtoReceipt(r)
	}
	return protoList
}

func FromProtoReceiptList(protoList []*ReceiptProto) []*receipts.Receipt {
	if protoList == nil {
		return nil
	}
	receiptsList := make([]*receipts.Receipt, len(protoList))
	for i, p := range protoList {
		receiptsList[i] = FromProtoReceipt(p)
	}
	return receiptsList
}
