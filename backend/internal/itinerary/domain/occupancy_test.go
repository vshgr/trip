package domain

import "testing"

func TestScheduleOccupancyMergesOverlappingIntervals(t *testing.T) {
	result := ScheduleOccupancy([]Interval{
		{StartMinute: 9 * 60, EndMinute: 11 * 60},
		{StartMinute: 10 * 60, EndMinute: 12 * 60},
	})

	if result.OccupiedMinutes != 180 {
		t.Fatalf("expected 180 occupied minutes, got %d", result.OccupiedMinutes)
	}
}

func TestScheduleOccupancyClipsToActiveDay(t *testing.T) {
	result := ScheduleOccupancy([]Interval{
		{StartMinute: 7 * 60, EndMinute: 9 * 60},
		{StartMinute: 22 * 60, EndMinute: 24 * 60},
	})

	if result.OccupiedMinutes != 120 {
		t.Fatalf("expected 120 occupied minutes, got %d", result.OccupiedMinutes)
	}
}

func TestScheduleOccupancyEmpty(t *testing.T) {
	result := ScheduleOccupancy(nil)

	if result.OccupiedMinutes != 0 || result.Percent != 0 || result.AvailableMinutes != ActiveDayMinutes {
		t.Fatalf("unexpected occupancy: %+v", result)
	}
}
