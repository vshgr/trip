package domain

import "sort"

const (
	ActiveDayStartMinute = 8 * 60
	ActiveDayMinutes     = 15 * 60
)

type Interval struct {
	StartMinute int
	EndMinute   int
}

type Occupancy struct {
	OccupiedMinutes  int
	AvailableMinutes int
	Percent          int
}

func ScheduleOccupancy(intervals []Interval) Occupancy {
	availableEnd := ActiveDayStartMinute + ActiveDayMinutes
	clipped := make([]Interval, 0, len(intervals))
	for _, interval := range intervals {
		start := max(interval.StartMinute, ActiveDayStartMinute)
		end := min(interval.EndMinute, availableEnd)
		if end > start {
			clipped = append(clipped, Interval{StartMinute: start, EndMinute: end})
		}
	}

	sort.Slice(clipped, func(i, j int) bool {
		if clipped[i].StartMinute == clipped[j].StartMinute {
			return clipped[i].EndMinute < clipped[j].EndMinute
		}
		return clipped[i].StartMinute < clipped[j].StartMinute
	})

	occupied := 0
	var current *Interval
	for _, interval := range clipped {
		if current == nil {
			value := interval
			current = &value
			continue
		}

		if interval.StartMinute <= current.EndMinute {
			current.EndMinute = max(current.EndMinute, interval.EndMinute)
			continue
		}

		occupied += current.EndMinute - current.StartMinute
		value := interval
		current = &value
	}

	if current != nil {
		occupied += current.EndMinute - current.StartMinute
	}

	percent := int(float64(occupied)/float64(ActiveDayMinutes)*100 + 0.5)
	percent = min(100, max(0, percent))
	return Occupancy{OccupiedMinutes: occupied, AvailableMinutes: ActiveDayMinutes, Percent: percent}
}
