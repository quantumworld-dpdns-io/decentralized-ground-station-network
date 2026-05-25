package scheduling

import (
	"context"
	"fmt"
	"math"
	"sort"
	"time"
)

type Algorithm interface {
	Schedule(ctx context.Context, slots []*ScheduleSlot, constraints map[string]interface{}) ([]*ScheduleResult, error)
	Score(slot *ScheduleSlot) float64
	DetectConflicts(slot *ScheduleSlot, existing []*ScheduleSlot) []Conflict
}

type GreedyAlgorithm struct{}

func NewGreedyAlgorithm() Algorithm {
	return &GreedyAlgorithm{}
}

func (a *GreedyAlgorithm) Schedule(ctx context.Context, slots []*ScheduleSlot, constraints map[string]interface{}) ([]*ScheduleResult, error) {
	if len(slots) == 0 {
		return nil, nil
	}

	sorted := make([]*ScheduleSlot, len(slots))
	copy(sorted, slots)

	sort.Slice(sorted, func(i, j int) bool {
		scoreI := a.Score(sorted[i])
		scoreJ := a.Score(sorted[j])
		if scoreI != scoreJ {
			return scoreI > scoreJ
		}
		return sorted[i].StartTime.Before(sorted[j].StartTime)
	})

	var results []*ScheduleResult
	assigned := make(map[string]bool)

	for _, slot := range sorted {
		if assigned[slot.ID] {
			continue
		}

		result := &ScheduleResult{
			Slot:  slot,
			Score: a.Score(slot),
		}

		for _, other := range sorted {
			if other.ID == slot.ID || assigned[other.ID] {
				continue
			}
			conflicts := a.DetectConflicts(slot, []*ScheduleSlot{other})
			result.Conflicts = append(result.Conflicts, conflicts...)
		}

		assigned[slot.ID] = true
		results = append(results, result)
	}

	return results, nil
}

func (a *GreedyAlgorithm) Score(slot *ScheduleSlot) float64 {
	score := 50.0

	switch slot.Priority {
	case PriorityLow:
		score += 10
	case PriorityNormal:
		score += 25
	case PriorityHigh:
		score += 50
	case PriorityCritical:
		score += 100
	}

	duration := slot.EndTime.Sub(slot.StartTime).Minutes()
	score += math.Min(duration, 120.0) / 120.0 * 30

	now := time.Now()
	if slot.StartTime.Before(now) {
		urgency := now.Sub(slot.StartTime).Minutes()
		score += math.Min(urgency, 1440.0) / 1440.0 * 20
	}

	return score
}

func (a *GreedyAlgorithm) DetectConflicts(slot *ScheduleSlot, existing []*ScheduleSlot) []Conflict {
	var conflicts []Conflict

	for _, other := range existing {
		if slot.StationID == other.StationID {
			if slot.StartTime.Before(other.EndTime) && slot.EndTime.After(other.StartTime) {
				conflicts = append(conflicts, Conflict{
					Type:          "time_overlap",
					Message:       fmt.Sprintf("slot %s overlaps with slot %s on station %s", slot.ID, other.ID, slot.StationID),
					ConflictingID: other.ID,
					Severity:      "error",
				})
			}
		}

		if slot.AssignedTo != "" && slot.AssignedTo == other.AssignedTo {
			if slot.StartTime.Before(other.EndTime) && slot.EndTime.After(other.StartTime) {
				conflicts = append(conflicts, Conflict{
					Type:          "user_overlap",
					Message:       fmt.Sprintf("user %s is already assigned to slot %s during this time", slot.AssignedTo, other.ID),
					ConflictingID: other.ID,
					Severity:      "warning",
				})
			}
		}
	}

	return conflicts
}

type WeightedAlgorithm struct {
	timeWeight     float64
	priorityWeight float64
	stationWeight  float64
}

func NewWeightedAlgorithm(timeWeight, priorityWeight, stationWeight float64) Algorithm {
	return &WeightedAlgorithm{
		timeWeight:     timeWeight,
		priorityWeight: priorityWeight,
		stationWeight:  stationWeight,
	}
}

func (a *WeightedAlgorithm) Schedule(ctx context.Context, slots []*ScheduleSlot, constraints map[string]interface{}) ([]*ScheduleResult, error) {
	if len(slots) == 0 {
		return nil, nil
	}

	sorted := make([]*ScheduleSlot, len(slots))
	copy(sorted, slots)

	sort.Slice(sorted, func(i, j int) bool {
		return a.Score(sorted[i]) > a.Score(sorted[j])
	})

	var results []*ScheduleResult
	assigned := make(map[string]bool)

	for _, slot := range sorted {
		if assigned[slot.ID] {
			continue
		}

		result := &ScheduleResult{
			Slot:  slot,
			Score: a.Score(slot),
		}

		for _, other := range sorted {
			if other.ID == slot.ID || assigned[other.ID] {
				continue
			}
			conflicts := a.DetectConflicts(slot, []*ScheduleSlot{other})
			result.Conflicts = append(result.Conflicts, conflicts...)
		}

		assigned[slot.ID] = true
		results = append(results, result)
	}

	return results, nil
}

func (a *WeightedAlgorithm) Score(slot *ScheduleSlot) float64 {
	priorityVal := float64(slot.Priority) * a.priorityWeight

	duration := slot.EndTime.Sub(slot.StartTime).Minutes()
	timeVal := math.Min(duration, 120.0) / 120.0 * 100 * a.timeWeight

	now := time.Now()
	urgency := 0.0
	if slot.StartTime.Before(now) {
		urgency = math.Min(now.Sub(slot.StartTime).Minutes(), 1440.0) / 1440.0 * 50
	}

	return priorityVal + timeVal + urgency
}

func (a *WeightedAlgorithm) DetectConflicts(slot *ScheduleSlot, existing []*ScheduleSlot) []Conflict {
	algo := &GreedyAlgorithm{}
	return algo.DetectConflicts(slot, existing)
}
