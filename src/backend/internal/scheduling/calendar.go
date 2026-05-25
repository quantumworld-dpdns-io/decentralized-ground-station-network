package scheduling

import (
	"context"
	"fmt"
	"sort"
	"time"
)

type CalendarService interface {
	GetCalendar(ctx context.Context, stationID string, year, month int) (*CalendarView, error)
	GetCalendarRange(ctx context.Context, stationID string, from, to time.Time) ([]*CalendarEntry, error)
}

type calendarService struct {
	slotRepo  SlotRepository
	assignRepo AssignmentRepository
}

type CalendarView struct {
	StationID string           `json:"station_id"`
	Year      int              `json:"year"`
	Month     int              `json:"month"`
	Entries   []*CalendarEntry `json:"entries"`
	Summary   CalendarSummary  `json:"summary"`
}

type CalendarSummary struct {
	TotalSlots     int     `json:"total_slots"`
	UsedSlots      int     `json:"used_slots"`
	AvailableSlots int     `json:"available_slots"`
	Utilization    float64 `json:"utilization"`
	ByStatus       map[SlotStatus]int `json:"by_status"`
}

func NewCalendarService(slotRepo SlotRepository, assignRepo AssignmentRepository) CalendarService {
	return &calendarService{
		slotRepo:   slotRepo,
		assignRepo: assignRepo,
	}
}

func (s *calendarService) GetCalendar(ctx context.Context, stationID string, year, month int) (*CalendarView, error) {
	from := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	to := from.AddDate(0, 1, 0).Add(-time.Second)

	entries, err := s.GetCalendarRange(ctx, stationID, from, to)
	if err != nil {
		return nil, fmt.Errorf("getting calendar range: %w", err)
	}

	view := &CalendarView{
		StationID: stationID,
		Year:      year,
		Month:     month,
		Entries:   entries,
	}

	summary := CalendarSummary{
		ByStatus: make(map[SlotStatus]int),
	}
	for _, entry := range entries {
		summary.TotalSlots += entry.TotalSlots
		summary.UsedSlots += entry.UsedSlots
		for _, slot := range entry.Slots {
			summary.ByStatus[slot.Status]++
		}
	}
	summary.AvailableSlots = summary.TotalSlots - summary.UsedSlots
	if summary.TotalSlots > 0 {
		summary.Utilization = float64(summary.UsedSlots) / float64(summary.TotalSlots) * 100
	}
	view.Summary = summary

	return view, nil
}

func (s *calendarService) GetCalendarRange(ctx context.Context, stationID string, from, to time.Time) ([]*CalendarEntry, error) {
	slots, err := s.slotRepo.List(ctx, ScheduleFilter{
		StationID: stationID,
		FromTime:  &from,
		ToTime:    &to,
	})
	if err != nil {
		return nil, fmt.Errorf("listing slots for calendar: %w", err)
	}

	daysMap := make(map[string][]*ScheduleSlot)
	for _, slot := range slots {
		dayKey := slot.StartTime.Format("2006-01-02")
		daysMap[dayKey] = append(daysMap[dayKey], slot)
	}

	var dateKeys []string
	for k := range daysMap {
		dateKeys = append(dateKeys, k)
	}
	sort.Strings(dateKeys)

	var entries []*CalendarEntry
	for _, dateKey := range dateKeys {
		daySlots := daysMap[dateKey]
		used := 0
		for _, s := range daySlots {
			if s.Status != SlotStatusAvailable {
				used++
			}
		}
		entries = append(entries, &CalendarEntry{
			Date:       dateKey,
			Slots:      daySlots,
			TotalSlots: len(daySlots),
			UsedSlots:  used,
			Utilization: func() float64 {
				if len(daySlots) == 0 {
					return 0
				}
				return float64(used) / float64(len(daySlots)) * 100
			}(),
		})
	}

	return entries, nil
}
