package httpx

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const demoUserID = "11111111-1111-1111-1111-111111111111"

type TripWriteHandlers struct {
	db *pgxpool.Pool
}

func RegisterTripWriteHandlers(mux *http.ServeMux, db *pgxpool.Pool) {
	handlers := &TripWriteHandlers{db: db}

	mux.HandleFunc("POST /api/v1/trips", handlers.createTrip)
	mux.HandleFunc("PATCH /api/v1/trips/{trip_id}", handlers.updateTrip)
	mux.HandleFunc("DELETE /api/v1/trips/{trip_id}", handlers.deleteTrip)
	mux.HandleFunc("POST /api/v1/trips/{trip_id}/plan-items", handlers.createPlanItem)
	mux.HandleFunc("PATCH /api/v1/trips/{trip_id}/plan-items/{item_id}", handlers.updatePlanItem)
	mux.HandleFunc("DELETE /api/v1/trips/{trip_id}/plan-items/{item_id}", handlers.deletePlanItem)
	mux.HandleFunc("POST /api/v1/trips/{trip_id}/expenses", handlers.createExpense)
	mux.HandleFunc("PATCH /api/v1/trips/{trip_id}/expenses/{expense_id}", handlers.updateExpense)
	mux.HandleFunc("DELETE /api/v1/trips/{trip_id}/expenses/{expense_id}", handlers.deleteExpense)
	mux.HandleFunc("POST /api/v1/import/local-data", handlers.importLocalData)
}

func (h *TripWriteHandlers) createTrip(w http.ResponseWriter, r *http.Request) {
	var req createTripRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	tripID, err := h.createTripFromRequest(r.Context(), req)
	if err != nil {
		writeTripWriteError(w, r, err)
		return
	}
	read := &TripReadHandlers{db: h.db}
	trip, err := read.trip(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusCreated, Envelope{Data: trip})
}

func (h *TripWriteHandlers) updateTrip(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	var req updateTripRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	commandTag, err := h.db.Exec(r.Context(), `
UPDATE trips
SET
    title = COALESCE(NULLIF($2, ''), title),
    start_date = COALESCE(NULLIF($3, '')::date, start_date),
    end_date = COALESCE(NULLIF($4, '')::date, end_date),
    timezone = COALESCE($5, timezone),
    version = version + 1,
    updated_at = now()
WHERE id = $1 AND deleted_at IS NULL`, tripID, strings.TrimSpace(req.Title), stringValue(req.StartDate), stringValue(req.EndDate), nullableString(req.Timezone))
	if err != nil {
		writeTripWriteError(w, r, err)
		return
	}
	if commandTag.RowsAffected() == 0 {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Trip not found", RequestIDFromContext(r.Context()))
		return
	}

	read := &TripReadHandlers{db: h.db}
	trip, err := read.trip(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: trip})
}

func (h *TripWriteHandlers) deleteTrip(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	commandTag, err := h.db.Exec(r.Context(), `
UPDATE trips
SET deleted_at = now(), updated_at = now(), version = version + 1
WHERE id = $1 AND deleted_at IS NULL`, tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	if commandTag.RowsAffected() == 0 {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Trip not found", RequestIDFromContext(r.Context()))
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: map[string]string{"status": "deleted"}})
}

func (h *TripWriteHandlers) createPlanItem(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	var req createPlanItemRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	itemID, err := h.insertPlanItem(r.Context(), tripID, req)
	if err != nil {
		writeTripWriteError(w, r, err)
		return
	}
	var item PlanItemResponse
	err = h.db.QueryRow(r.Context(), `
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
WHERE p.id = $1`, itemID).Scan(
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
	)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusCreated, Envelope{Data: item})
}

func (h *TripWriteHandlers) createExpense(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	var req createExpenseRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	expenseID, err := h.insertExpense(r.Context(), tripID, req)
	if err != nil {
		writeTripWriteError(w, r, err)
		return
	}
	read := &TripReadHandlers{db: h.db}
	shares, _ := read.expenseShares(r.Context(), expenseID)
	var expense ExpenseResponse
	err = h.db.QueryRow(r.Context(), `
SELECT e.id::text, e.title, e.amount_minor, e.currency_code, e.paid_by_party_id::text, p.display_name, e.occurred_at, e.version
FROM expenses e
JOIN trip_parties p ON p.id = e.paid_by_party_id
WHERE e.id = $1`, expenseID).Scan(
		&expense.ID,
		&expense.Title,
		&expense.AmountMinor,
		&expense.Currency,
		&expense.PaidByPartyID,
		&expense.PaidByName,
		&expense.OccurredAt,
		&expense.Version,
	)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	expense.Shares = shares
	WriteJSON(w, http.StatusCreated, Envelope{Data: expense})
}

func (h *TripWriteHandlers) updatePlanItem(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	itemID := r.PathValue("item_id")
	var req updatePlanItemRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	cityName := stringPtrValue(req.City)
	if cityName == "" && req.CityID != nil && *req.CityID != "" {
		_ = h.db.QueryRow(r.Context(), "SELECT name FROM trip_cities WHERE id = $1 AND trip_id = $2", *req.CityID, tripID).Scan(&cityName)
	}

	commandTag, err := h.db.Exec(r.Context(), `
UPDATE plan_items
SET
    source_day_id = COALESCE(NULLIF($3, '')::uuid, source_day_id),
    title = COALESCE(NULLIF($4, ''), title),
    city_id = COALESCE(NULLIF($5, '')::uuid, city_id),
    city_name_snapshot = COALESCE(NULLIF($6, ''), city_name_snapshot),
    category = COALESCE(NULLIF($7, ''), category),
    schedule_type = COALESCE(NULLIF($8, ''), schedule_type),
    period = COALESCE($9, period),
    start_at = COALESCE($10, start_at),
    end_at = COALESCE($11, end_at),
    timezone = COALESCE(NULLIF($12, ''), timezone),
    sort_index = COALESCE($13, sort_index),
    needs_ticket = COALESCE($14, needs_ticket),
    ticket_bought = COALESCE($15, ticket_bought),
    version = version + 1,
    updated_at = now()
WHERE trip_id = $1 AND id = $2 AND deleted_at IS NULL`,
		tripID,
		itemID,
		stringPtrValue(req.SourceDayID),
		stringPtrValue(req.Title),
		stringPtrValue(req.CityID),
		cityName,
		stringPtrValue(req.Category),
		stringPtrValue(req.ScheduleType),
		req.Period,
		req.StartAt,
		req.EndAt,
		stringPtrValue(req.Timezone),
		req.SortIndex,
		req.NeedsTicket,
		req.TicketBought,
	)
	if err != nil {
		writeTripWriteError(w, r, err)
		return
	}
	if commandTag.RowsAffected() == 0 {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Plan item not found", RequestIDFromContext(r.Context()))
		return
	}

	read := &TripReadHandlers{db: h.db}
	items, err := read.planItems(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	for _, item := range items {
		if item.ID == itemID {
			WriteJSON(w, http.StatusOK, Envelope{Data: item})
			return
		}
	}
	WriteError(w, http.StatusNotFound, "NOT_FOUND", "Plan item not found", RequestIDFromContext(r.Context()))
}

func (h *TripWriteHandlers) deletePlanItem(w http.ResponseWriter, r *http.Request) {
	commandTag, err := h.db.Exec(r.Context(), `
UPDATE plan_items
SET deleted_at = now(), updated_at = now(), version = version + 1
WHERE trip_id = $1 AND id = $2 AND deleted_at IS NULL`, r.PathValue("trip_id"), r.PathValue("item_id"))
	if err != nil {
		writeInternalError(w, r)
		return
	}
	if commandTag.RowsAffected() == 0 {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Plan item not found", RequestIDFromContext(r.Context()))
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: map[string]string{"status": "deleted"}})
}

func (h *TripWriteHandlers) updateExpense(w http.ResponseWriter, r *http.Request) {
	tripID := r.PathValue("trip_id")
	expenseID := r.PathValue("expense_id")
	var req updateExpenseRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		writeInternalError(w, r)
		return
	}
	defer tx.Rollback(r.Context())

	commandTag, err := tx.Exec(r.Context(), `
UPDATE expenses
SET
    title = COALESCE(NULLIF($3, ''), title),
    amount_minor = COALESCE($4, amount_minor),
    currency_code = COALESCE(NULLIF($5, ''), currency_code),
    paid_by_party_id = COALESCE(NULLIF($6, '')::uuid, paid_by_party_id),
    occurred_at = COALESCE($7, occurred_at),
    category = COALESCE($8, category),
    note = COALESCE($9, note),
    version = version + 1,
    updated_at = now()
WHERE trip_id = $1 AND id = $2 AND deleted_at IS NULL`,
		tripID,
		expenseID,
		stringPtrValue(req.Title),
		req.AmountMinor,
		strings.ToUpper(stringPtrValue(req.Currency)),
		stringPtrValue(req.PaidByPartyID),
		req.OccurredAt,
		req.Category,
		req.Note,
	)
	if err != nil {
		writeTripWriteError(w, r, err)
		return
	}
	if commandTag.RowsAffected() == 0 {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Expense not found", RequestIDFromContext(r.Context()))
		return
	}
	if req.Shares != nil {
		var amount int64
		if err := tx.QueryRow(r.Context(), "SELECT amount_minor FROM expenses WHERE id = $1", expenseID).Scan(&amount); err != nil {
			writeInternalError(w, r)
			return
		}
		total := int64(0)
		for _, share := range *req.Shares {
			total += share.ShareMinor
		}
		if total != amount {
			WriteError(w, http.StatusBadRequest, "EXPENSE_SHARES_MISMATCH", "Expense shares must sum to amount_minor", RequestIDFromContext(r.Context()))
			return
		}
		if _, err := tx.Exec(r.Context(), "DELETE FROM expense_shares WHERE expense_id = $1", expenseID); err != nil {
			writeInternalError(w, r)
			return
		}
		for _, share := range *req.Shares {
			_, err = tx.Exec(r.Context(), `
INSERT INTO expense_shares (id, expense_id, party_id, share_minor, created_at)
VALUES ($1, $2, $3, $4, now())`, newUUID(), expenseID, share.PartyID, share.ShareMinor)
			if err != nil {
				writeTripWriteError(w, r, err)
				return
			}
		}
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeInternalError(w, r)
		return
	}

	read := &TripReadHandlers{db: h.db}
	expenses, err := read.expenses(r.Context(), tripID)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	for _, expense := range expenses {
		if expense.ID == expenseID {
			WriteJSON(w, http.StatusOK, Envelope{Data: expense})
			return
		}
	}
	WriteError(w, http.StatusNotFound, "NOT_FOUND", "Expense not found", RequestIDFromContext(r.Context()))
}

func (h *TripWriteHandlers) deleteExpense(w http.ResponseWriter, r *http.Request) {
	commandTag, err := h.db.Exec(r.Context(), `
UPDATE expenses
SET deleted_at = now(), updated_at = now(), version = version + 1
WHERE trip_id = $1 AND id = $2 AND deleted_at IS NULL`, r.PathValue("trip_id"), r.PathValue("expense_id"))
	if err != nil {
		writeInternalError(w, r)
		return
	}
	if commandTag.RowsAffected() == 0 {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Expense not found", RequestIDFromContext(r.Context()))
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: map[string]string{"status": "deleted"}})
}

func (h *TripWriteHandlers) importLocalData(w http.ResponseWriter, r *http.Request) {
	var req importLocalDataRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	created := []string{}
	for _, trip := range req.Trips {
		tripID, err := h.createTripFromRequest(r.Context(), trip)
		if err != nil {
			writeTripWriteError(w, r, err)
			return
		}
		created = append(created, tripID)
	}
	WriteJSON(w, http.StatusCreated, Envelope{Data: map[string]any{"created_trip_ids": created}})
}

func (h *TripWriteHandlers) createTripFromRequest(ctx context.Context, req createTripRequest) (string, error) {
	req.Title = strings.TrimSpace(req.Title)
	if req.Title == "" || req.StartDate == "" || req.EndDate == "" {
		return "", errValidation
	}
	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return "", errValidation
	}
	endDate, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil || endDate.Before(startDate) {
		return "", errValidation
	}
	ownerID := req.OwnerID
	if ownerID == "" {
		ownerID = demoUserID
	}

	tx, err := h.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	tripID := newUUID()
	now := time.Now().UTC()
	_, err = tx.Exec(ctx, `
INSERT INTO trips (id, owner_id, client_id, title, start_date, end_date, timezone, cover_image_url, version, created_at, updated_at, deleted_at)
VALUES ($1, $2, $1, $3, $4, $5, $6, NULL, 1, $7, $7, NULL)`, tripID, ownerID, req.Title, req.StartDate, req.EndDate, nullableString(req.Timezone), now)
	if err != nil {
		return "", err
	}
	_, err = tx.Exec(ctx, `
INSERT INTO trip_members (id, trip_id, user_id, role, joined_at)
VALUES ($1, $2, $3, 'owner', $4)`, newUUID(), tripID, ownerID, now)
	if err != nil {
		return "", err
	}

	cityIDs := map[string]string{}
	for index, name := range req.Cities {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		cityID := newUUID()
		cityIDs[name] = cityID
		_, err = tx.Exec(ctx, `
INSERT INTO trip_cities (id, trip_id, name, sort_order, created_at)
VALUES ($1, $2, $3, $4, $5)`, cityID, tripID, name, index, now)
		if err != nil {
			return "", err
		}
	}
	for _, name := range req.Parties {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		_, err = tx.Exec(ctx, `
INSERT INTO trip_parties (id, trip_id, user_id, display_name, created_at)
VALUES ($1, $2, NULL, $3, $4)`, newUUID(), tripID, name, now)
		if err != nil {
			return "", err
		}
	}
	if len(req.Days) == 0 {
		req.Days = generatedDays(startDate, endDate, req.Cities)
	}
	for index, day := range req.Days {
		if day.Date == "" {
			return "", errValidation
		}
		cityID := cityIDs[day.City]
		_, err = tx.Exec(ctx, `
INSERT INTO trip_days (id, trip_id, client_id, local_id, date, city_id, city_name_snapshot, sort_order, version, created_at, updated_at)
VALUES ($1, $2, NULL, $3, $4, NULLIF($5, '')::uuid, NULLIF($6, ''), $7, 1, $8, $8)`,
			newUUID(),
			tripID,
			nullableString(day.LocalID),
			day.Date,
			cityID,
			day.City,
			index,
			now,
		)
		if err != nil {
			return "", err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return tripID, nil
}

func (h *TripWriteHandlers) insertPlanItem(ctx context.Context, tripID string, req createPlanItemRequest) (string, error) {
	req.Title = strings.TrimSpace(req.Title)
	if req.Title == "" || req.SourceDayID == "" {
		return "", errValidation
	}
	if req.Category == "" {
		req.Category = "sight"
	}
	if req.ScheduleType == "" {
		req.ScheduleType = "unscheduled"
	}
	if req.ScheduleType == "exact" && (req.StartAt == nil || req.Timezone == "") {
		return "", errValidation
	}
	cityName := req.City
	if cityName == "" && req.CityID != "" {
		_ = h.db.QueryRow(ctx, "SELECT name FROM trip_cities WHERE id = $1 AND trip_id = $2", req.CityID, tripID).Scan(&cityName)
	}
	itemID := newUUID()
	err := h.db.QueryRow(ctx, `
INSERT INTO plan_items (
    id, trip_id, client_id, source_day_id, title, city_id, city_name_snapshot, category,
    schedule_type, period, start_at, end_at, timezone, sort_index, needs_ticket, ticket_bought,
    version, created_by, created_at, updated_at, deleted_at
)
VALUES ($1, $2, NULL, $3, $4, NULLIF($5, '')::uuid, NULLIF($6, ''), $7, $8, $9, $10, $11, $12, $13, $14, $15, 1, $16, now(), now(), NULL)
RETURNING id::text`,
		itemID,
		tripID,
		req.SourceDayID,
		req.Title,
		req.CityID,
		cityName,
		req.Category,
		req.ScheduleType,
		nullableString(req.Period),
		req.StartAt,
		req.EndAt,
		nullableString(req.Timezone),
		req.SortIndex,
		req.NeedsTicket,
		req.TicketBought,
		demoUserID,
	).Scan(&itemID)
	if err != nil {
		return "", err
	}
	return itemID, nil
}

func (h *TripWriteHandlers) insertExpense(ctx context.Context, tripID string, req createExpenseRequest) (string, error) {
	req.Title = strings.TrimSpace(req.Title)
	req.Currency = strings.ToUpper(strings.TrimSpace(req.Currency))
	if req.Title == "" || req.AmountMinor <= 0 || req.Currency == "" || req.PaidByPartyID == "" {
		return "", errValidation
	}
	occurredAt := time.Now().UTC()
	if req.OccurredAt != nil {
		occurredAt = *req.OccurredAt
	}
	if len(req.Shares) == 0 {
		shares, err := h.equalShares(ctx, tripID, req.AmountMinor)
		if err != nil {
			return "", err
		}
		req.Shares = shares
	}
	totalShares := int64(0)
	for _, share := range req.Shares {
		totalShares += share.ShareMinor
	}
	if totalShares != req.AmountMinor {
		return "", errSharesMismatch
	}

	tx, err := h.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	expenseID := newUUID()
	_, err = tx.Exec(ctx, `
INSERT INTO expenses (
    id, trip_id, client_id, title, amount_minor, currency_code, paid_by_party_id, occurred_at,
    category, note, version, created_by, created_at, updated_at, deleted_at
)
VALUES ($1, $2, NULL, $3, $4, $5, $6, $7, NULLIF($8, ''), NULLIF($9, ''), 1, $10, now(), now(), NULL)`,
		expenseID,
		tripID,
		req.Title,
		req.AmountMinor,
		req.Currency,
		req.PaidByPartyID,
		occurredAt,
		req.Category,
		req.Note,
		demoUserID,
	)
	if err != nil {
		return "", err
	}
	for _, share := range req.Shares {
		_, err = tx.Exec(ctx, `
INSERT INTO expense_shares (id, expense_id, party_id, share_minor, created_at)
VALUES ($1, $2, $3, $4, now())`, newUUID(), expenseID, share.PartyID, share.ShareMinor)
		if err != nil {
			return "", err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return expenseID, nil
}

func (h *TripWriteHandlers) equalShares(ctx context.Context, tripID string, amount int64) ([]expenseShareInput, error) {
	rows, err := h.db.Query(ctx, `
SELECT id::text
FROM trip_parties
WHERE trip_id = $1
ORDER BY created_at, display_name`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	partyIDs := []string{}
	for rows.Next() {
		var partyID string
		if err := rows.Scan(&partyID); err != nil {
			return nil, err
		}
		partyIDs = append(partyIDs, partyID)
	}
	if rows.Err() != nil {
		return nil, rows.Err()
	}
	if len(partyIDs) == 0 {
		return nil, errValidation
	}
	base := amount / int64(len(partyIDs))
	remainder := amount % int64(len(partyIDs))
	shares := []expenseShareInput{}
	for index, partyID := range partyIDs {
		share := base
		if int64(index) < remainder {
			share++
		}
		shares = append(shares, expenseShareInput{PartyID: partyID, ShareMinor: share})
	}
	return shares, nil
}

func generatedDays(startDate time.Time, endDate time.Time, cities []string) []tripDayInput {
	days := []tripDayInput{}
	index := 0
	for date := startDate; !date.After(endDate); date = date.AddDate(0, 0, 1) {
		city := ""
		if len(cities) > 0 {
			city = cities[min(index, len(cities)-1)]
		}
		days = append(days, tripDayInput{
			LocalID: strconv.Itoa(index),
			Date:    date.Format("2006-01-02"),
			City:    city,
		})
		index++
	}
	return days
}

func stringValue(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func stringPtrValue(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(*value)
}

func writeTripWriteError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, errValidation):
		WriteError(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body", RequestIDFromContext(r.Context()))
	case errors.Is(err, errSharesMismatch):
		WriteError(w, http.StatusBadRequest, "EXPENSE_SHARES_MISMATCH", "Expense shares must sum to amount_minor", RequestIDFromContext(r.Context()))
	case errors.Is(err, pgx.ErrNoRows):
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Resource not found", RequestIDFromContext(r.Context()))
	default:
		writeInternalError(w, r)
	}
}

var (
	errValidation     = errors.New("validation error")
	errSharesMismatch = errors.New("expense shares mismatch")
)

type createTripRequest struct {
	OwnerID   string         `json:"owner_id"`
	Title     string         `json:"title"`
	StartDate string         `json:"start_date"`
	EndDate   string         `json:"end_date"`
	Timezone  string         `json:"timezone"`
	Cities    []string       `json:"cities"`
	Parties   []string       `json:"parties"`
	Days      []tripDayInput `json:"days"`
}

type updateTripRequest struct {
	Title     string  `json:"title"`
	StartDate *string `json:"start_date"`
	EndDate   *string `json:"end_date"`
	Timezone  string  `json:"timezone"`
}

type tripDayInput struct {
	LocalID string `json:"local_id"`
	Date    string `json:"date"`
	City    string `json:"city"`
}

type createPlanItemRequest struct {
	SourceDayID  string     `json:"source_day_id"`
	Title        string     `json:"title"`
	CityID       string     `json:"city_id"`
	City         string     `json:"city"`
	Category     string     `json:"category"`
	ScheduleType string     `json:"schedule_type"`
	Period       string     `json:"period"`
	StartAt      *time.Time `json:"start_at"`
	EndAt        *time.Time `json:"end_at"`
	Timezone     string     `json:"timezone"`
	SortIndex    int        `json:"sort_index"`
	NeedsTicket  bool       `json:"needs_ticket"`
	TicketBought bool       `json:"ticket_bought"`
}

type updatePlanItemRequest struct {
	SourceDayID  *string    `json:"source_day_id"`
	Title        *string    `json:"title"`
	CityID       *string    `json:"city_id"`
	City         *string    `json:"city"`
	Category     *string    `json:"category"`
	ScheduleType *string    `json:"schedule_type"`
	Period       *string    `json:"period"`
	StartAt      *time.Time `json:"start_at"`
	EndAt        *time.Time `json:"end_at"`
	Timezone     *string    `json:"timezone"`
	SortIndex    *int       `json:"sort_index"`
	NeedsTicket  *bool      `json:"needs_ticket"`
	TicketBought *bool      `json:"ticket_bought"`
}

type createExpenseRequest struct {
	Title         string              `json:"title"`
	AmountMinor   int64               `json:"amount_minor"`
	Currency      string              `json:"currency"`
	PaidByPartyID string              `json:"paid_by_party_id"`
	OccurredAt    *time.Time          `json:"occurred_at"`
	Category      string              `json:"category"`
	Note          string              `json:"note"`
	Shares        []expenseShareInput `json:"shares"`
}

type updateExpenseRequest struct {
	Title         *string              `json:"title"`
	AmountMinor   *int64               `json:"amount_minor"`
	Currency      *string              `json:"currency"`
	PaidByPartyID *string              `json:"paid_by_party_id"`
	OccurredAt    *time.Time           `json:"occurred_at"`
	Category      *string              `json:"category"`
	Note          *string              `json:"note"`
	Shares        *[]expenseShareInput `json:"shares"`
}

type expenseShareInput struct {
	PartyID    string `json:"party_id"`
	ShareMinor int64  `json:"share_minor"`
}

type importLocalDataRequest struct {
	Trips []createTripRequest `json:"trips"`
}
