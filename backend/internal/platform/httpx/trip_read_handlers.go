package httpx

import (
	"context"
	"net/http"
	"sort"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	itinerarydomain "github.com/vshgr/trip/backend/internal/itinerary/domain"
)

type TripReadHandlers struct {
	db *pgxpool.Pool
}

func RegisterTripReadHandlers(mux *http.ServeMux, db *pgxpool.Pool) {
	handlers := &TripReadHandlers{db: db}

	mux.HandleFunc("GET /api/v1/trips", handlers.listTrips)
	mux.HandleFunc("GET /api/v1/trips/{trip_id}", handlers.getTrip)
	mux.HandleFunc("GET /api/v1/trips/{trip_id}/days", handlers.listDays)
	mux.HandleFunc("GET /api/v1/trips/{trip_id}/plan-items", handlers.listPlanItems)
	mux.HandleFunc("GET /api/v1/trips/{trip_id}/schedule-progress", handlers.getScheduleProgress)
	mux.HandleFunc("GET /api/v1/trips/{trip_id}/expenses", handlers.listExpenses)
	mux.HandleFunc("GET /api/v1/trips/{trip_id}/balances", handlers.getBalances)
	mux.HandleFunc("GET /api/v1/trips/{trip_id}/widget", handlers.getWidget)
}

func (h *TripReadHandlers) listTrips(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	rows, err := h.db.Query(ctx, `
SELECT
    t.id::text,
    t.title,
    t.start_date::text,
    t.end_date::text,
    t.updated_at,
    t.version
FROM trips t
WHERE t.deleted_at IS NULL
ORDER BY t.updated_at DESC`)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	defer rows.Close()

	trips := []TripSummary{}
	for rows.Next() {
		var trip TripSummary
		if err := rows.Scan(&trip.ID, &trip.Title, &trip.StartDate, &trip.EndDate, &trip.UpdatedAt, &trip.Version); err != nil {
			writeInternalError(w, r)
			return
		}
		trip.Cities, _ = h.tripCities(ctx, trip.ID)
		trip.MemberCount, _ = h.partyCount(ctx, trip.ID)
		trip.ExpenseTotalsByCurrency, _ = h.expenseTotals(ctx, trip.ID)
		trip.ScheduleOccupancyPercent, _ = h.tripOccupancyPercent(ctx, trip.ID)
		trip.NearestActivity, _ = h.nearestActivity(ctx, trip.ID)
		trips = append(trips, trip)
	}
	if rows.Err() != nil {
		writeInternalError(w, r)
		return
	}

	WriteJSON(w, http.StatusOK, Envelope{Data: trips, Meta: map[string]any{"next_cursor": nil}})
}

func (h *TripReadHandlers) getTrip(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	trip, err := h.trip(r.Context(), tripID)
	if err != nil {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Trip not found", RequestIDFromContext(r.Context()))
		return
	}

	WriteJSON(w, http.StatusOK, Envelope{Data: trip})
}

func (h *TripReadHandlers) listDays(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	rows, err := h.db.Query(r.Context(), `
SELECT
    d.id::text,
    d.local_id,
    d.date::text,
    COALESCE(d.city_name_snapshot, c.name, ''),
    d.sort_order,
    d.version
FROM trip_days d
LEFT JOIN trip_cities c ON c.id = d.city_id
WHERE d.trip_id = $1
ORDER BY d.sort_order`, tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	defer rows.Close()

	days := []TripDayResponse{}
	for rows.Next() {
		var day TripDayResponse
		if err := rows.Scan(&day.ID, &day.LocalID, &day.Date, &day.City, &day.SortOrder, &day.Version); err != nil {
			writeInternalError(w, r)
			return
		}
		occupancy, _ := h.dayOccupancy(r.Context(), tripID, day.ID)
		day.ScheduleOccupancyPercent = occupancy.Percent
		days = append(days, day)
	}

	WriteJSON(w, http.StatusOK, Envelope{Data: days, Meta: map[string]any{"next_cursor": nil}})
}

func (h *TripReadHandlers) listPlanItems(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	items, err := h.planItems(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: items, Meta: map[string]any{"next_cursor": nil}})
}

func (h *TripReadHandlers) getScheduleProgress(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	days, err := h.scheduleProgress(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}

	totalOccupied := 0
	totalAvailable := 0
	for _, day := range days {
		totalOccupied += day.OccupiedMinutes
		totalAvailable += day.AvailableMinutes
	}

	tripPercent := 0
	if totalAvailable > 0 {
		tripPercent = int(float64(totalOccupied)/float64(totalAvailable)*100 + 0.5)
	}

	WriteJSON(w, http.StatusOK, Envelope{Data: ScheduleProgressResponse{TripPercent: tripPercent, Days: days}})
}

func (h *TripReadHandlers) listExpenses(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	expenses, err := h.expenses(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}

	WriteJSON(w, http.StatusOK, Envelope{Data: expenses, Meta: map[string]any{"next_cursor": nil}})
}

func (h *TripReadHandlers) getBalances(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	response, err := h.balances(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}

	WriteJSON(w, http.StatusOK, Envelope{Data: response})
}

func (h *TripReadHandlers) getWidget(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	trip, err := h.trip(r.Context(), tripID)
	if err != nil {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Trip not found", RequestIDFromContext(r.Context()))
		return
	}
	days, err := h.days(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	progress, _ := h.tripOccupancyPercent(r.Context(), tripID)
	nearest, _ := h.nearestActivity(r.Context(), tripID)

	var nextCity *WidgetCity
	today := time.Now().UTC()
	for index, day := range days {
		date, err := time.Parse("2006-01-02", day.Date)
		if err != nil || date.Before(today.Truncate(24*time.Hour)) {
			continue
		}
		if index == 0 || days[index-1].City != day.City {
			daysUntil := int(date.Sub(today.Truncate(24*time.Hour)).Hours() / 24)
			nextCity = &WidgetCity{Name: day.City, Date: day.Date, DaysUntil: max(0, daysUntil)}
			break
		}
	}

	var plannedDay *WidgetPlannedDay
	for _, day := range days {
		if nearest != nil && nearest.SourceDayID == day.ID {
			plannedDay = &WidgetPlannedDay{Date: day.Date}
			break
		}
	}

	WriteJSON(w, http.StatusOK, Envelope{Data: WidgetResponse{
		TripID:               trip.ID,
		TripTitle:            trip.Title,
		NextCity:             nextCity,
		NearestPlannedDay:    plannedDay,
		NearestActivity:      nearest,
		RouteProgressPercent: progress,
		GeneratedAt:          time.Now().UTC(),
	}})
}

func (h *TripReadHandlers) trip(ctx context.Context, tripID string) (TripResponse, error) {
	var trip TripResponse
	err := h.db.QueryRow(ctx, `
SELECT id::text, title, start_date::text, end_date::text, timezone, version, created_at, updated_at
FROM trips
WHERE id = $1 AND deleted_at IS NULL`, tripID).Scan(
		&trip.ID,
		&trip.Title,
		&trip.StartDate,
		&trip.EndDate,
		&trip.Timezone,
		&trip.Version,
		&trip.CreatedAt,
		&trip.UpdatedAt,
	)
	if err != nil {
		return TripResponse{}, err
	}

	trip.Cities, _ = h.tripCities(ctx, tripID)
	trip.Parties, _ = h.tripParties(ctx, tripID)
	return trip, nil
}

func (h *TripReadHandlers) tripCities(ctx context.Context, tripID string) ([]TripCityResponse, error) {
	rows, err := h.db.Query(ctx, `
SELECT id::text, name, sort_order
FROM trip_cities
WHERE trip_id = $1
ORDER BY sort_order`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cities := []TripCityResponse{}
	for rows.Next() {
		var city TripCityResponse
		if err := rows.Scan(&city.ID, &city.Name, &city.SortOrder); err != nil {
			return nil, err
		}
		cities = append(cities, city)
	}
	return cities, rows.Err()
}

func (h *TripReadHandlers) tripParties(ctx context.Context, tripID string) ([]TripPartyResponse, error) {
	rows, err := h.db.Query(ctx, `
SELECT id::text, display_name
FROM trip_parties
WHERE trip_id = $1
ORDER BY created_at, display_name`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	parties := []TripPartyResponse{}
	for rows.Next() {
		var party TripPartyResponse
		if err := rows.Scan(&party.ID, &party.DisplayName); err != nil {
			return nil, err
		}
		parties = append(parties, party)
	}
	return parties, rows.Err()
}

func (h *TripReadHandlers) partyCount(ctx context.Context, tripID string) (int, error) {
	var count int
	err := h.db.QueryRow(ctx, "SELECT count(*) FROM trip_parties WHERE trip_id = $1", tripID).Scan(&count)
	return count, err
}

func (h *TripReadHandlers) days(ctx context.Context, tripID string) ([]TripDayResponse, error) {
	rows, err := h.db.Query(ctx, `
SELECT id::text, local_id, date::text, COALESCE(city_name_snapshot, ''), sort_order, version
FROM trip_days
WHERE trip_id = $1
ORDER BY sort_order`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	days := []TripDayResponse{}
	for rows.Next() {
		var day TripDayResponse
		if err := rows.Scan(&day.ID, &day.LocalID, &day.Date, &day.City, &day.SortOrder, &day.Version); err != nil {
			return nil, err
		}
		days = append(days, day)
	}
	return days, rows.Err()
}

func (h *TripReadHandlers) planItems(ctx context.Context, tripID string) ([]PlanItemResponse, error) {
	rows, err := h.db.Query(ctx, `
SELECT
    p.id::text,
    p.source_day_id::text,
    p.title,
    COALESCE(p.city_name_snapshot, c.name, ''),
    p.category,
    p.schedule_type,
    p.period,
    p.start_at,
    p.end_at,
    p.timezone,
    p.sort_index,
    p.needs_ticket,
    p.ticket_bought,
    p.version
FROM plan_items p
LEFT JOIN trip_cities c ON c.id = p.city_id
WHERE p.trip_id = $1 AND p.deleted_at IS NULL
ORDER BY p.source_day_id, p.sort_index`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []PlanItemResponse{}
	for rows.Next() {
		var item PlanItemResponse
		if err := rows.Scan(
			&item.ID,
			&item.SourceDayID,
			&item.Title,
			&item.City,
			&item.Category,
			&item.ScheduleType,
			&item.Period,
			&item.StartAt,
			&item.EndAt,
			&item.Timezone,
			&item.SortIndex,
			&item.NeedsTicket,
			&item.TicketBought,
			&item.Version,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (h *TripReadHandlers) expenses(ctx context.Context, tripID string) ([]ExpenseResponse, error) {
	rows, err := h.db.Query(ctx, `
SELECT
    e.id::text,
    e.title,
    e.amount_minor,
    e.currency_code,
    e.paid_by_party_id::text,
    payer.display_name,
    e.occurred_at,
    e.version
FROM expenses e
JOIN trip_parties payer ON payer.id = e.paid_by_party_id
WHERE e.trip_id = $1 AND e.deleted_at IS NULL
ORDER BY e.occurred_at DESC`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	expenses := []ExpenseResponse{}
	for rows.Next() {
		var expense ExpenseResponse
		if err := rows.Scan(
			&expense.ID,
			&expense.Title,
			&expense.AmountMinor,
			&expense.Currency,
			&expense.PaidByPartyID,
			&expense.PaidByName,
			&expense.OccurredAt,
			&expense.Version,
		); err != nil {
			return nil, err
		}
		expense.Shares, _ = h.expenseShares(ctx, expense.ID)
		expenses = append(expenses, expense)
	}
	return expenses, rows.Err()
}

func (h *TripReadHandlers) expenseShares(ctx context.Context, expenseID string) ([]ExpenseShareResponse, error) {
	rows, err := h.db.Query(ctx, `
SELECT s.id::text, s.party_id::text, p.display_name, s.share_minor
FROM expense_shares s
JOIN trip_parties p ON p.id = s.party_id
WHERE s.expense_id = $1
ORDER BY p.display_name`, expenseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	shares := []ExpenseShareResponse{}
	for rows.Next() {
		var share ExpenseShareResponse
		if err := rows.Scan(&share.ID, &share.PartyID, &share.PartyName, &share.ShareMinor); err != nil {
			return nil, err
		}
		shares = append(shares, share)
	}
	return shares, rows.Err()
}

func (h *TripReadHandlers) expenseTotals(ctx context.Context, tripID string) (map[string]int64, error) {
	rows, err := h.db.Query(ctx, `
SELECT currency_code, COALESCE(sum(amount_minor), 0)::bigint
FROM expenses
WHERE trip_id = $1 AND deleted_at IS NULL
GROUP BY currency_code`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	totals := map[string]int64{}
	for rows.Next() {
		var currency string
		var amount int64
		if err := rows.Scan(&currency, &amount); err != nil {
			return nil, err
		}
		totals[currency] = amount
	}
	return totals, rows.Err()
}

func (h *TripReadHandlers) balances(ctx context.Context, tripID string) (BalancesResponse, error) {
	rows, err := h.db.Query(ctx, `
SELECT
    e.id::text,
    e.currency_code,
    e.amount_minor,
    e.paid_by_party_id::text,
    payer.display_name,
    s.party_id::text,
    party.display_name,
    s.share_minor
FROM expenses e
JOIN trip_parties payer ON payer.id = e.paid_by_party_id
JOIN expense_shares s ON s.expense_id = e.id
JOIN trip_parties party ON party.id = s.party_id
WHERE e.trip_id = $1 AND e.deleted_at IS NULL`, tripID)
	if err != nil {
		return BalancesResponse{}, err
	}
	defer rows.Close()

	type balanceDraft struct {
		partyID string
		name    string
		balance int64
	}
	byCurrency := map[string]map[string]*balanceDraft{}
	seenExpenses := map[string]bool{}
	for rows.Next() {
		var expenseID string
		var currency string
		var amount int64
		var payerID string
		var payerName string
		var partyID string
		var partyName string
		var share int64
		if err := rows.Scan(&expenseID, &currency, &amount, &payerID, &payerName, &partyID, &partyName, &share); err != nil {
			return BalancesResponse{}, err
		}
		if byCurrency[currency] == nil {
			byCurrency[currency] = map[string]*balanceDraft{}
		}
		if byCurrency[currency][payerID] == nil {
			byCurrency[currency][payerID] = &balanceDraft{partyID: payerID, name: payerName}
		}
		if byCurrency[currency][partyID] == nil {
			byCurrency[currency][partyID] = &balanceDraft{partyID: partyID, name: partyName}
		}
		if !seenExpenses[expenseID] {
			byCurrency[currency][payerID].balance += amount
			seenExpenses[expenseID] = true
		}
		byCurrency[currency][partyID].balance -= share
	}
	if rows.Err() != nil {
		return BalancesResponse{}, rows.Err()
	}

	currencies := []CurrencyBalanceResponse{}
	for currency, drafts := range byCurrency {
		members := []MemberBalanceResponse{}
		for _, draft := range drafts {
			members = append(members, MemberBalanceResponse{PartyID: draft.partyID, DisplayName: draft.name, BalanceMinor: draft.balance})
		}
		sort.Slice(members, func(i, j int) bool { return members[i].DisplayName < members[j].DisplayName })
		currencies = append(currencies, CurrencyBalanceResponse{
			Currency:            currency,
			Members:             members,
			SimplifiedTransfers: simplifiedTransfers(members),
		})
	}
	sort.Slice(currencies, func(i, j int) bool { return currencies[i].Currency < currencies[j].Currency })
	return BalancesResponse{Currencies: currencies}, nil
}

func simplifiedTransfers(members []MemberBalanceResponse) []TransferResponse {
	debtors := []MemberBalanceResponse{}
	creditors := []MemberBalanceResponse{}
	for _, member := range members {
		if member.BalanceMinor < 0 {
			member.BalanceMinor = -member.BalanceMinor
			debtors = append(debtors, member)
		}
		if member.BalanceMinor > 0 {
			creditors = append(creditors, member)
		}
	}
	sort.Slice(debtors, func(i, j int) bool { return debtors[i].BalanceMinor > debtors[j].BalanceMinor })
	sort.Slice(creditors, func(i, j int) bool { return creditors[i].BalanceMinor > creditors[j].BalanceMinor })

	transfers := []TransferResponse{}
	debtorIndex := 0
	creditorIndex := 0
	for debtorIndex < len(debtors) && creditorIndex < len(creditors) {
		amount := min(debtors[debtorIndex].BalanceMinor, creditors[creditorIndex].BalanceMinor)
		if amount > 0 {
			transfers = append(transfers, TransferResponse{
				FromPartyID: debtors[debtorIndex].PartyID,
				FromName:    debtors[debtorIndex].DisplayName,
				ToPartyID:   creditors[creditorIndex].PartyID,
				ToName:      creditors[creditorIndex].DisplayName,
				AmountMinor: amount,
			})
		}
		debtors[debtorIndex].BalanceMinor -= amount
		creditors[creditorIndex].BalanceMinor -= amount
		if debtors[debtorIndex].BalanceMinor == 0 {
			debtorIndex++
		}
		if creditors[creditorIndex].BalanceMinor == 0 {
			creditorIndex++
		}
	}
	return transfers
}

func (h *TripReadHandlers) scheduleProgress(ctx context.Context, tripID string) ([]DayScheduleProgressResponse, error) {
	days, err := h.days(ctx, tripID)
	if err != nil {
		return nil, err
	}
	progress := []DayScheduleProgressResponse{}
	for _, day := range days {
		occupancy, err := h.dayOccupancy(ctx, tripID, day.ID)
		if err != nil {
			return nil, err
		}
		progress = append(progress, DayScheduleProgressResponse{
			DayID:            day.ID,
			Date:             day.Date,
			OccupiedMinutes:  occupancy.OccupiedMinutes,
			AvailableMinutes: occupancy.AvailableMinutes,
			Percent:          occupancy.Percent,
		})
	}
	return progress, nil
}

func (h *TripReadHandlers) dayOccupancy(ctx context.Context, tripID string, dayID string) (itinerarydomain.Occupancy, error) {
	var dateText string
	if err := h.db.QueryRow(ctx, "SELECT date::text FROM trip_days WHERE id = $1 AND trip_id = $2", dayID, tripID).Scan(&dateText); err != nil {
		return itinerarydomain.Occupancy{}, err
	}
	dayDate, err := time.Parse("2006-01-02", dateText)
	if err != nil {
		return itinerarydomain.Occupancy{}, err
	}
	startBoundary := time.Date(dayDate.Year(), dayDate.Month(), dayDate.Day(), 0, 0, 0, 0, time.UTC)

	rows, err := h.db.Query(ctx, `
SELECT start_at, end_at
FROM plan_items
WHERE trip_id = $1
  AND schedule_type = 'exact'
  AND deleted_at IS NULL
  AND start_at IS NOT NULL`, tripID)
	if err != nil {
		return itinerarydomain.Occupancy{}, err
	}
	defer rows.Close()

	intervals := []itinerarydomain.Interval{}
	for rows.Next() {
		var startAt time.Time
		var endAt *time.Time
		if err := rows.Scan(&startAt, &endAt); err != nil {
			return itinerarydomain.Occupancy{}, err
		}
		end := startAt.Add(time.Hour)
		if endAt != nil {
			end = *endAt
		}
		intervals = append(intervals, itinerarydomain.Interval{
			StartMinute: int(startAt.UTC().Sub(startBoundary).Minutes()),
			EndMinute:   int(end.UTC().Sub(startBoundary).Minutes()),
		})
	}
	return itinerarydomain.ScheduleOccupancy(intervals), rows.Err()
}

func (h *TripReadHandlers) tripOccupancyPercent(ctx context.Context, tripID string) (int, error) {
	progress, err := h.scheduleProgress(ctx, tripID)
	if err != nil {
		return 0, err
	}
	totalOccupied := 0
	totalAvailable := 0
	for _, day := range progress {
		totalOccupied += day.OccupiedMinutes
		totalAvailable += day.AvailableMinutes
	}
	if totalAvailable == 0 {
		return 0, nil
	}
	return int(float64(totalOccupied)/float64(totalAvailable)*100 + 0.5), nil
}

func (h *TripReadHandlers) nearestActivity(ctx context.Context, tripID string) (*NearestActivityResponse, error) {
	var activity NearestActivityResponse
	err := h.db.QueryRow(ctx, `
SELECT id::text, source_day_id::text, title, start_at, period
FROM plan_items
WHERE trip_id = $1 AND deleted_at IS NULL
ORDER BY
    CASE WHEN start_at IS NULL THEN 1 ELSE 0 END,
    start_at,
    sort_index
LIMIT 1`, tripID).Scan(&activity.ID, &activity.SourceDayID, &activity.Title, &activity.StartAt, &activity.Period)
	if err != nil {
		return nil, nil
	}
	return &activity, nil
}

func writeInternalError(w http.ResponseWriter, r *http.Request) {
	WriteError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Internal server error", RequestIDFromContext(r.Context()))
}

type TripSummary struct {
	ID                       string                   `json:"id"`
	Title                    string                   `json:"title"`
	StartDate                string                   `json:"start_date"`
	EndDate                  string                   `json:"end_date"`
	Cities                   []TripCityResponse       `json:"cities"`
	MemberCount              int                      `json:"member_count"`
	ScheduleOccupancyPercent int                      `json:"schedule_occupancy_percent"`
	ExpenseTotalsByCurrency  map[string]int64         `json:"expense_totals_by_currency"`
	ApproximateTotalRub      *int64                   `json:"approximate_total_rub"`
	NearestActivity          *NearestActivityResponse `json:"nearest_activity"`
	UpdatedAt                time.Time                `json:"updated_at"`
	Version                  int64                    `json:"version"`
}

type TripResponse struct {
	ID        string              `json:"id"`
	Title     string              `json:"title"`
	StartDate string              `json:"start_date"`
	EndDate   string              `json:"end_date"`
	Timezone  *string             `json:"timezone"`
	Cities    []TripCityResponse  `json:"cities"`
	Parties   []TripPartyResponse `json:"parties"`
	Version   int64               `json:"version"`
	CreatedAt time.Time           `json:"created_at"`
	UpdatedAt time.Time           `json:"updated_at"`
}

type TripCityResponse struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	SortOrder int    `json:"sort_order"`
}

type TripPartyResponse struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
}

type TripDayResponse struct {
	ID                       string  `json:"id"`
	LocalID                  *string `json:"local_id"`
	Date                     string  `json:"date"`
	City                     string  `json:"city"`
	SortOrder                int     `json:"sort_order"`
	ScheduleOccupancyPercent int     `json:"schedule_occupancy_percent"`
	Version                  int64   `json:"version"`
}

type PlanItemResponse struct {
	ID           string     `json:"id"`
	SourceDayID  string     `json:"source_day_id"`
	Title        string     `json:"title"`
	City         string     `json:"city"`
	Category     string     `json:"category"`
	ScheduleType string     `json:"schedule_type"`
	Period       *string    `json:"period"`
	StartAt      *time.Time `json:"start_at"`
	EndAt        *time.Time `json:"end_at"`
	Timezone     *string    `json:"timezone"`
	SortIndex    int        `json:"sort_index"`
	NeedsTicket  bool       `json:"needs_ticket"`
	TicketBought bool       `json:"ticket_bought"`
	Version      int64      `json:"version"`
}

type ExpenseResponse struct {
	ID            string                 `json:"id"`
	Title         string                 `json:"title"`
	AmountMinor   int64                  `json:"amount_minor"`
	Currency      string                 `json:"currency"`
	PaidByPartyID string                 `json:"paid_by_party_id"`
	PaidByName    string                 `json:"paid_by_name"`
	OccurredAt    time.Time              `json:"occurred_at"`
	Shares        []ExpenseShareResponse `json:"shares"`
	Version       int64                  `json:"version"`
}

type ExpenseShareResponse struct {
	ID         string `json:"id"`
	PartyID    string `json:"party_id"`
	PartyName  string `json:"party_name"`
	ShareMinor int64  `json:"share_minor"`
}

type BalancesResponse struct {
	Currencies []CurrencyBalanceResponse `json:"currencies"`
}

type CurrencyBalanceResponse struct {
	Currency            string                  `json:"currency"`
	Members             []MemberBalanceResponse `json:"members"`
	SimplifiedTransfers []TransferResponse      `json:"simplified_transfers"`
}

type MemberBalanceResponse struct {
	PartyID      string `json:"party_id"`
	DisplayName  string `json:"display_name"`
	BalanceMinor int64  `json:"balance_minor"`
}

type TransferResponse struct {
	FromPartyID string `json:"from_party_id"`
	FromName    string `json:"from_name"`
	ToPartyID   string `json:"to_party_id"`
	ToName      string `json:"to_name"`
	AmountMinor int64  `json:"amount_minor"`
}

type ScheduleProgressResponse struct {
	TripPercent int                           `json:"trip_percent"`
	Days        []DayScheduleProgressResponse `json:"days"`
}

type DayScheduleProgressResponse struct {
	DayID            string `json:"day_id"`
	Date             string `json:"date"`
	OccupiedMinutes  int    `json:"occupied_minutes"`
	AvailableMinutes int    `json:"available_minutes"`
	Percent          int    `json:"percent"`
}

type WidgetResponse struct {
	TripID               string                   `json:"trip_id"`
	TripTitle            string                   `json:"trip_title"`
	NextCity             *WidgetCity              `json:"next_city"`
	NearestPlannedDay    *WidgetPlannedDay        `json:"nearest_planned_day"`
	NearestActivity      *NearestActivityResponse `json:"nearest_activity"`
	RouteProgressPercent int                      `json:"route_progress_percent"`
	GeneratedAt          time.Time                `json:"generated_at"`
}

type WidgetCity struct {
	Name      string `json:"name"`
	Date      string `json:"date"`
	DaysUntil int    `json:"days_until"`
}

type WidgetPlannedDay struct {
	Date string `json:"date"`
}

type NearestActivityResponse struct {
	ID          string     `json:"id"`
	SourceDayID string     `json:"source_day_id"`
	Title       string     `json:"title"`
	StartAt     *time.Time `json:"start_at"`
	Period      *string    `json:"period"`
}
