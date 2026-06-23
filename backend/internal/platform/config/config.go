package config

import (
	"errors"
	"os"
	"time"
)

type Config struct {
	AppEnv              string
	HTTPPort           string
	HTTPReadTimeout    time.Duration
	HTTPWriteTimeout   time.Duration
	HTTPIdleTimeout    time.Duration
	HTTPShutdownTimeout time.Duration
	DatabaseURL        string
	LogLevel           string
}

func Load() (Config, error) {
	cfg := Config{
		AppEnv:              env("APP_ENV", "local"),
		HTTPPort:           env("HTTP_PORT", "8080"),
		HTTPReadTimeout:    durationEnv("HTTP_READ_TIMEOUT", 10*time.Second),
		HTTPWriteTimeout:   durationEnv("HTTP_WRITE_TIMEOUT", 15*time.Second),
		HTTPIdleTimeout:    durationEnv("HTTP_IDLE_TIMEOUT", 60*time.Second),
		HTTPShutdownTimeout: durationEnv("HTTP_SHUTDOWN_TIMEOUT", 10*time.Second),
		DatabaseURL:        env("DATABASE_URL", ""),
		LogLevel:           env("LOG_LEVEL", "debug"),
	}

	if cfg.HTTPPort == "" {
		return Config{}, errors.New("HTTP_PORT is required")
	}

	return cfg, nil
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func durationEnv(key string, fallback time.Duration) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}
	return parsed
}
