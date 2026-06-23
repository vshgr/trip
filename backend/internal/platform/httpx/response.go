package httpx

import (
	"encoding/json"
	"net/http"
)

type Envelope struct {
	Data any `json:"data,omitempty"`
	Meta any `json:"meta,omitempty"`
}

type ErrorEnvelope struct {
	Error APIError `json:"error"`
}

type APIError struct {
	Code      string       `json:"code"`
	Message   string       `json:"message"`
	Details   []FieldError `json:"details,omitempty"`
	RequestID string       `json:"request_id"`
}

type FieldError struct {
	Field  string `json:"field"`
	Reason string `json:"reason"`
}

func WriteJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func WriteError(w http.ResponseWriter, status int, code, message, requestID string) {
	WriteJSON(w, status, ErrorEnvelope{
		Error: APIError{
			Code:      code,
			Message:   message,
			RequestID: requestID,
		},
	})
}
