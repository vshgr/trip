package httpx

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vshgr/trip/backend/internal/platform/database"
)

func NewRouter(logger *slog.Logger, db database.Pinger, jwtSecret string) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health/live", func(w http.ResponseWriter, r *http.Request) {
		WriteJSON(w, http.StatusOK, Envelope{Data: map[string]string{"status": "ok"}})
	})

	mux.HandleFunc("GET /health/ready", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()

		if err := db.Ping(ctx); err != nil {
			WriteError(w, http.StatusServiceUnavailable, "INTERNAL_ERROR", "Database is not ready", RequestIDFromContext(r.Context()))
			return
		}

		WriteJSON(w, http.StatusOK, Envelope{Data: map[string]string{"status": "ready"}})
	})

	if provider, ok := db.(interface{ Raw() *pgxpool.Pool }); ok {
		RegisterTripReadHandlers(mux, provider.Raw())
		RegisterTripWriteHandlers(mux, provider.Raw())
		RegisterAuthHandlers(mux, provider.Raw(), jwtSecret)
	}

	var handler http.Handler = mux
	handler = AccessLog(logger)(handler)
	handler = Recover(logger)(handler)
	handler = RequestID(handler)
	return handler
}
