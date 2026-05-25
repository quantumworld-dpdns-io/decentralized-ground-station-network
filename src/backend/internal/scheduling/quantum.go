package scheduling

import (
	"context"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/quantumworld-dpdns-io/dgsn/pkg/quantum"
)

type QuantumScheduler interface {
	Schedule(ctx context.Context, slots []*ScheduleSlot, constraints map[string]interface{}) ([]*ScheduleResult, error)
	Optimize(ctx context.Context, assignments []*Assignment) ([]*Assignment, error)
}

type quantumScheduler struct {
	client      quantum.Client
	baseAlgo    Algorithm
	maxQubits   int
}

func NewQuantumScheduler(client quantum.Client, baseAlgo Algorithm, maxQubits int) QuantumScheduler {
	return &quantumScheduler{
		client:    client,
		baseAlgo:  baseAlgo,
		maxQubits: maxQubits,
	}
}

func (qs *quantumScheduler) Schedule(ctx context.Context, slots []*ScheduleSlot, constraints map[string]interface{}) ([]*ScheduleResult, error) {
	if len(slots) == 0 {
		return nil, nil
	}

	if len(slots) <= qs.maxQubits && qs.client != nil {
		return qs.quantumSchedule(ctx, slots, constraints)
	}

	return qs.baseAlgo.Schedule(ctx, slots, constraints)
}

func (qs *quantumScheduler) quantumSchedule(ctx context.Context, slots []*ScheduleSlot, constraints map[string]interface{}) ([]*ScheduleResult, error) {
	type variable struct {
		slot    *ScheduleSlot
		qubit   int
		assigned bool
	}

	variables := make([]variable, len(slots))
	for i, slot := range slots {
		variables[i] = variable{slot: slot, qubit: i}
	}

	circuit, err := qs.buildCircuit(variables)
	if err != nil {
		return nil, fmt.Errorf("building quantum circuit: %w", err)
	}

	result, err := qs.client.Execute(ctx, circuit)
	if err != nil {
		return nil, fmt.Errorf("executing quantum circuit: %w", err)
	}

	assignments := qs.decodeResult(result, variables)
	sort.Slice(assignments, func(i, j int) bool {
		return assignments[i].Score > assignments[j].Score
	})

	var results []*ScheduleResult
	assigned := make(map[string]bool)

	for _, a := range assignments {
		if assigned[a.slot.ID] {
			continue
		}
		res := &ScheduleResult{
			Slot:  a.slot,
			Score: a.Score,
		}
		for _, v := range variables {
			if v.slot.ID != a.slot.ID && !assigned[v.slot.ID] {
				conflicts := qs.baseAlgo.DetectConflicts(a.slot, []*ScheduleSlot{v.slot})
				res.Conflicts = append(res.Conflicts, conflicts...)
			}
		}
		assigned[a.slot.ID] = true
		results = append(results, res)
	}

	return results, nil
}

func (qs *quantumScheduler) buildCircuit(variables []variable) (*quantum.Circuit, error {
	qc := quantum.NewCircuit(len(variables), "qaoa")

	for i, v := range variables {
		theta := qs.computeAngle(v.slot)
		qc.AddGate(quantum.Gate{
			Type:   "ry",
			Qubits: []int{v.qubit},
			Params: map[string]float64{"theta": theta},
		})
	}

	for i := 0; i < len(variables)-1; i++ {
		for j := i + 1; j < len(variables); j++ {
			if qs.hasConstraint(variables[i].slot, variables[j].slot) {
				qc.AddGate(quantum.Gate{
					Type:   "rzz",
					Qubits: []int{variables[i].qubit, variables[j].qubit},
					Params: map[string]float64{"theta": math.Pi / 4},
				})
			}
		}
	}

	return qc, nil
}

func (qs *quantumScheduler) decodeResult(result *quantum.Result, variables []variable) []struct {
	slot  *ScheduleSlot
	Score float64
} {
	type scored struct {
		slot  *ScheduleSlot
		Score float64
	}

	assignments := make([]scored, len(variables))

	for i, v := range variables {
		prob := 0.5
		if result != nil && i < len(result.Counts) {
			prob = result.Counts[i]
		}
		assignments[i] = scored{
			slot:  v.slot,
			Score: qs.baseAlgo.Score(v.slot) * prob,
		}
	}

	return assignments
}

func (qs *quantumScheduler) computeAngle(slot *ScheduleSlot) float64 {
	baseAngle := float64(slot.Priority) * math.Pi / 6.0
	duration := slot.EndTime.Sub(slot.StartTime).Minutes()
	durationAngle := math.Min(duration, 120.0) / 120.0 * math.Pi / 4.0
	return baseAngle + durationAngle
}

func (qs *quantumScheduler) hasConstraint(a, b *ScheduleSlot) bool {
	if a.StationID == b.StationID {
		return a.StartTime.Before(b.EndTime) && a.EndTime.After(b.StartTime)
	}
	return false
}

func (qs *quantumScheduler) Optimize(ctx context.Context, assignments []*Assignment) ([]*Assignment, error) {
	if len(assignments) == 0 {
		return assignments, nil
	}

	sort.Slice(assignments, func(i, j int) bool {
		if assignments[i].Priority != assignments[j].Priority {
			return assignments[i].Priority > assignments[j].Priority
		}
		return assignments[i].StartTime.Before(assignments[j].StartTime)
	})

	return assignments, nil
}
