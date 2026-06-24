package httpx

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	accessTokenTTL  = 15 * time.Minute
	refreshTokenTTL = 30 * 24 * time.Hour
)

type AuthHandlers struct {
	db        *pgxpool.Pool
	jwtSecret []byte
}

func RegisterAuthHandlers(mux *http.ServeMux, db *pgxpool.Pool, jwtSecret string) {
	handlers := &AuthHandlers{db: db, jwtSecret: []byte(jwtSecret)}

	mux.HandleFunc("POST /api/v1/auth/register", handlers.register)
	mux.HandleFunc("POST /api/v1/auth/login", handlers.login)
	mux.HandleFunc("POST /api/v1/auth/refresh", handlers.refresh)
	mux.HandleFunc("POST /api/v1/auth/logout", handlers.logout)
	mux.HandleFunc("POST /api/v1/auth/yandex", handlers.yandex)
	mux.HandleFunc("GET /api/v1/me", handlers.getMe)
	mux.HandleFunc("PATCH /api/v1/me", handlers.updateMe)
}

func (h *AuthHandlers) register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if req.Email == "" || req.DisplayName == "" || len(req.Password) < 8 {
		WriteError(w, http.StatusBadRequest, "VALIDATION_ERROR", "email, display_name and password with at least 8 characters are required", RequestIDFromContext(r.Context()))
		return
	}

	userID := newUUID()
	now := time.Now().UTC()
	passwordHash, err := hashPassword(req.Password)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	_, err = h.db.Exec(r.Context(), `
INSERT INTO users (id, email, display_name, role, password_hash, avatar_url, created_at, updated_at)
VALUES ($1, $2, $3, 'user', $4, NULL, $5, $5)`, userID, req.Email, req.DisplayName, passwordHash, now)
	if err != nil {
		WriteError(w, http.StatusConflict, "CONFLICT", "User already exists", RequestIDFromContext(r.Context()))
		return
	}

	response, err := h.issueSession(r.Context(), userID, req.Email, req.DisplayName, "user", req.DeviceID, req.DeviceName)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusCreated, Envelope{Data: response})
}

func (h *AuthHandlers) login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	var user authUser
	err := h.db.QueryRow(r.Context(), `
SELECT id::text, email::text, display_name, role, password_hash
FROM users
WHERE email = $1`, req.Email).Scan(&user.ID, &user.Email, &user.DisplayName, &user.Role, &user.PasswordHash)
	if errors.Is(err, pgx.ErrNoRows) {
		WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Invalid email or password", RequestIDFromContext(r.Context()))
		return
	}
	if err != nil || !verifyPassword(req.Password, user.PasswordHash) {
		WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Invalid email or password", RequestIDFromContext(r.Context()))
		return
	}

	response, err := h.issueSession(r.Context(), user.ID, user.Email, user.DisplayName, user.Role, req.DeviceID, req.DeviceName)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: response})
}

func (h *AuthHandlers) refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	refreshHash := tokenHash(req.RefreshToken)

	var sessionID string
	var user authUser
	err := h.db.QueryRow(r.Context(), `
SELECT s.id::text, u.id::text, u.email::text, u.display_name, u.role, u.password_hash
FROM user_sessions s
JOIN users u ON u.id = s.user_id
WHERE s.refresh_token_hash = $1 AND s.revoked_at IS NULL AND s.expires_at > now()`, refreshHash).Scan(
		&sessionID,
		&user.ID,
		&user.Email,
		&user.DisplayName,
		&user.Role,
		&user.PasswordHash,
	)
	if err != nil {
		WriteError(w, http.StatusUnauthorized, "TOKEN_EXPIRED", "Refresh token is invalid or expired", RequestIDFromContext(r.Context()))
		return
	}

	_, _ = h.db.Exec(r.Context(), "UPDATE user_sessions SET revoked_at = now() WHERE id = $1", sessionID)
	response, err := h.issueSession(r.Context(), user.ID, user.Email, user.DisplayName, user.Role, "", "")
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: response})
}

func (h *AuthHandlers) logout(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.RefreshToken != "" {
		_, _ = h.db.Exec(r.Context(), "UPDATE user_sessions SET revoked_at = now() WHERE refresh_token_hash = $1", tokenHash(req.RefreshToken))
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: map[string]string{"status": "ok"}})
}

func (h *AuthHandlers) yandex(w http.ResponseWriter, r *http.Request) {
	var req yandexAuthRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.OAuthToken = strings.TrimSpace(req.OAuthToken)
	if req.OAuthToken == "" {
		WriteError(w, http.StatusBadRequest, "VALIDATION_ERROR", "oauth_token is required", RequestIDFromContext(r.Context()))
		return
	}

	profile, err := fetchYandexProfile(r.Context(), req.OAuthToken)
	if err != nil {
		WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Yandex token is invalid", RequestIDFromContext(r.Context()))
		return
	}
	user, err := h.upsertYandexUser(r.Context(), profile)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	response, err := h.issueSession(r.Context(), user.ID, user.Email, user.DisplayName, user.Role, req.DeviceID, req.DeviceName)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: response})
}

func (h *AuthHandlers) getMe(w http.ResponseWriter, r *http.Request) {
	user, ok := h.currentUser(w, r)
	if !ok {
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: user})
}

func (h *AuthHandlers) updateMe(w http.ResponseWriter, r *http.Request) {
	user, ok := h.currentUser(w, r)
	if !ok {
		return
	}
	var req updateMeRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if req.DisplayName == "" {
		WriteError(w, http.StatusBadRequest, "VALIDATION_ERROR", "display_name is required", RequestIDFromContext(r.Context()))
		return
	}
	err := h.db.QueryRow(r.Context(), `
UPDATE users
SET display_name = $2, updated_at = now()
WHERE id = $1
RETURNING id::text, email::text, display_name, role, avatar_url`, user.ID, req.DisplayName).Scan(
		&user.ID,
		&user.Email,
		&user.DisplayName,
		&user.Role,
		&user.AvatarURL,
	)
	if err != nil {
		writeInternalError(w, r)
		return
	}
	WriteJSON(w, http.StatusOK, Envelope{Data: user})
}

func (h *AuthHandlers) currentUser(w http.ResponseWriter, r *http.Request) (MeResponse, bool) {
	claims, err := h.parseAccessToken(bearerToken(r))
	if err != nil {
		WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Bearer token is required", RequestIDFromContext(r.Context()))
		return MeResponse{}, false
	}
	var user MeResponse
	err = h.db.QueryRow(r.Context(), `
SELECT id::text, email::text, display_name, role, avatar_url
FROM users
WHERE id = $1`, claims.Subject).Scan(&user.ID, &user.Email, &user.DisplayName, &user.Role, &user.AvatarURL)
	if err != nil {
		WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not found", RequestIDFromContext(r.Context()))
		return MeResponse{}, false
	}
	return user, true
}

func (h *AuthHandlers) issueSession(ctx context.Context, userID string, email string, displayName string, role string, deviceID string, deviceName string) (AuthResponse, error) {
	accessToken, expiresAt, err := h.accessToken(userID, email, displayName, role)
	if err != nil {
		return AuthResponse{}, err
	}
	refreshToken, err := randomToken(32)
	if err != nil {
		return AuthResponse{}, err
	}
	sessionID := newUUID()
	_, err = h.db.Exec(ctx, `
INSERT INTO user_sessions (id, user_id, refresh_token_hash, expires_at, revoked_at, device_id, device_name, created_at)
VALUES ($1, $2, $3, $4, NULL, $5, $6, now())`, sessionID, userID, tokenHash(refreshToken), time.Now().UTC().Add(refreshTokenTTL), nullableString(deviceID), nullableString(deviceName))
	if err != nil {
		return AuthResponse{}, err
	}

	return AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresAt:    expiresAt,
		User: MeResponse{
			ID:          userID,
			Email:       email,
			DisplayName: displayName,
			Role:        role,
		},
	}, nil
}

func (h *AuthHandlers) upsertYandexUser(ctx context.Context, profile yandexProfile) (authUser, error) {
	var user authUser
	err := h.db.QueryRow(ctx, `
SELECT u.id::text, u.email::text, u.display_name, u.role, COALESCE(u.password_hash, '')
FROM user_identity_providers p
JOIN users u ON u.id = p.user_id
WHERE p.provider = 'yandex' AND p.provider_subject = $1`, profile.ID).Scan(&user.ID, &user.Email, &user.DisplayName, &user.Role, &user.PasswordHash)
	if err == nil {
		_, _ = h.db.Exec(ctx, `
UPDATE user_identity_providers
SET email = $2, display_name = $3, avatar_url = $4, updated_at = now()
WHERE provider = 'yandex' AND provider_subject = $1`, profile.ID, profile.Email(), profile.DisplayName(), profile.AvatarURL())
		return user, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return authUser{}, err
	}

	email := profile.Email()
	if email == "" {
		email = fmt.Sprintf("yandex-%s@users.local", profile.ID)
	}
	displayName := profile.DisplayName()
	if displayName == "" {
		displayName = profile.Login
	}
	if displayName == "" {
		displayName = "Yandex User"
	}

	tx, err := h.db.Begin(ctx)
	if err != nil {
		return authUser{}, err
	}
	defer tx.Rollback(ctx)

	err = tx.QueryRow(ctx, `
SELECT id::text, email::text, display_name, role, COALESCE(password_hash, '')
FROM users
WHERE email = $1`, email).Scan(&user.ID, &user.Email, &user.DisplayName, &user.Role, &user.PasswordHash)
	if errors.Is(err, pgx.ErrNoRows) {
		user = authUser{ID: newUUID(), Email: email, DisplayName: displayName, Role: "user"}
		_, err = tx.Exec(ctx, `
INSERT INTO users (id, email, display_name, role, password_hash, avatar_url, created_at, updated_at)
VALUES ($1, $2, $3, 'user', NULL, $4, now(), now())`, user.ID, email, displayName, profile.AvatarURL())
	}
	if err != nil {
		return authUser{}, err
	}

	_, err = tx.Exec(ctx, `
INSERT INTO user_identity_providers (id, user_id, provider, provider_subject, email, display_name, avatar_url, created_at, updated_at)
VALUES ($1, $2, 'yandex', $3, $4, $5, $6, now(), now())
ON CONFLICT (provider, provider_subject) DO UPDATE
SET email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    avatar_url = EXCLUDED.avatar_url,
    updated_at = now()`, newUUID(), user.ID, profile.ID, email, displayName, profile.AvatarURL())
	if err != nil {
		return authUser{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return authUser{}, err
	}
	return user, nil
}

func fetchYandexProfile(ctx context.Context, oauthToken string) (yandexProfile, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://login.yandex.ru/info?format=json", nil)
	if err != nil {
		return yandexProfile{}, err
	}
	request.Header.Set("Authorization", "OAuth "+oauthToken)

	client := &http.Client{Timeout: 10 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return yandexProfile{}, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return yandexProfile{}, errors.New("yandex rejected token")
	}
	var profile yandexProfile
	if err := json.NewDecoder(response.Body).Decode(&profile); err != nil {
		return yandexProfile{}, err
	}
	if profile.ID == "" {
		return yandexProfile{}, errors.New("yandex id is empty")
	}
	return profile, nil
}

func (h *AuthHandlers) accessToken(userID string, email string, displayName string, role string) (string, time.Time, error) {
	expiresAt := time.Now().UTC().Add(accessTokenTTL)
	header := map[string]string{"alg": "HS256", "typ": "JWT"}
	claims := accessClaims{
		Subject:     userID,
		Email:       email,
		DisplayName: displayName,
		Role:        role,
		ExpiresAt:   expiresAt.Unix(),
	}
	headerJSON, err := json.Marshal(header)
	if err != nil {
		return "", time.Time{}, err
	}
	claimsJSON, err := json.Marshal(claims)
	if err != nil {
		return "", time.Time{}, err
	}
	unsigned := base64.RawURLEncoding.EncodeToString(headerJSON) + "." + base64.RawURLEncoding.EncodeToString(claimsJSON)
	signature := sign(unsigned, h.jwtSecret)
	return unsigned + "." + signature, expiresAt, nil
}

func (h *AuthHandlers) parseAccessToken(token string) (accessClaims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return accessClaims{}, errors.New("invalid token")
	}
	unsigned := parts[0] + "." + parts[1]
	if !hmac.Equal([]byte(parts[2]), []byte(sign(unsigned, h.jwtSecret))) {
		return accessClaims{}, errors.New("invalid signature")
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return accessClaims{}, err
	}
	var claims accessClaims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return accessClaims{}, err
	}
	if claims.ExpiresAt <= time.Now().UTC().Unix() {
		return accessClaims{}, errors.New("expired")
	}
	return claims, nil
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(dst); err != nil {
		WriteError(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid JSON body", RequestIDFromContext(r.Context()))
		return false
	}
	return true
}

func sign(value string, secret []byte) string {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(value))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func hashPassword(password string) (string, error) {
	salt, err := randomToken(16)
	if err != nil {
		return "", err
	}
	hash := derivePasswordKey(password, salt)
	return "hmac_sha256_v1$" + salt + "$" + hash, nil
}

func verifyPassword(password string, encoded string) bool {
	parts := strings.Split(encoded, "$")
	if len(parts) != 3 || parts[0] != "hmac_sha256_v1" {
		return false
	}
	expected := derivePasswordKey(password, parts[1])
	return hmac.Equal([]byte(expected), []byte(parts[2]))
}

func derivePasswordKey(password string, salt string) string {
	sum := []byte(password + ":" + salt)
	for range 120000 {
		hash := sha256.Sum256(sum)
		sum = hash[:]
	}
	return hex.EncodeToString(sum)
}

func randomToken(size int) (string, error) {
	bytes := make([]byte, size)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(bytes), nil
}

func tokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func bearerToken(r *http.Request) string {
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return ""
	}
	return strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
}

func nullableString(value string) *string {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return &value
}

type registerRequest struct {
	Email       string `json:"email"`
	DisplayName string `json:"display_name"`
	Password    string `json:"password"`
	DeviceID    string `json:"device_id"`
	DeviceName  string `json:"device_name"`
}

type loginRequest struct {
	Email      string `json:"email"`
	Password   string `json:"password"`
	DeviceID   string `json:"device_id"`
	DeviceName string `json:"device_name"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type yandexAuthRequest struct {
	OAuthToken string `json:"oauth_token"`
	DeviceID   string `json:"device_id"`
	DeviceName string `json:"device_name"`
}

type updateMeRequest struct {
	DisplayName string `json:"display_name"`
}

type accessClaims struct {
	Subject     string `json:"sub"`
	Email       string `json:"email"`
	DisplayName string `json:"display_name"`
	Role        string `json:"role"`
	ExpiresAt   int64  `json:"exp"`
}

type authUser struct {
	ID           string
	Email        string
	DisplayName  string
	Role         string
	PasswordHash string
}

type yandexProfile struct {
	ID              string   `json:"id"`
	Login           string   `json:"login"`
	DefaultEmail    string   `json:"default_email"`
	Emails          []string `json:"emails"`
	RealName        string   `json:"real_name"`
	DisplayNameRaw  string   `json:"display_name"`
	FirstName       string   `json:"first_name"`
	LastName        string   `json:"last_name"`
	DefaultAvatarID string   `json:"default_avatar_id"`
	IsAvatarEmpty   bool     `json:"is_avatar_empty"`
}

func (p yandexProfile) Email() string {
	if p.DefaultEmail != "" {
		return strings.ToLower(p.DefaultEmail)
	}
	if len(p.Emails) > 0 {
		return strings.ToLower(p.Emails[0])
	}
	return ""
}

func (p yandexProfile) DisplayName() string {
	if p.DisplayNameRaw != "" {
		return p.DisplayNameRaw
	}
	if p.RealName != "" {
		return p.RealName
	}
	name := strings.TrimSpace(p.FirstName + " " + p.LastName)
	if name != "" {
		return name
	}
	return p.Login
}

func (p yandexProfile) AvatarURL() *string {
	if p.IsAvatarEmpty || p.DefaultAvatarID == "" {
		return nil
	}
	value := "https://avatars.yandex.net/get-yapic/" + p.DefaultAvatarID + "/islands-200"
	return &value
}

type AuthResponse struct {
	AccessToken  string     `json:"access_token"`
	RefreshToken string     `json:"refresh_token"`
	TokenType    string     `json:"token_type"`
	ExpiresAt    time.Time  `json:"expires_at"`
	User         MeResponse `json:"user"`
}

type MeResponse struct {
	ID          string  `json:"id"`
	Email       string  `json:"email"`
	DisplayName string  `json:"display_name"`
	Role        string  `json:"role"`
	AvatarURL   *string `json:"avatar_url"`
}
