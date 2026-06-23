package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Pinger interface {
	Ping(ctx context.Context) error
	Close()
}

type Pool struct {
	pool *pgxpool.Pool
}

func Open(ctx context.Context, databaseURL string, maxConns int32, minConns int32) (*Pool, error) {
	if databaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database config: %w", err)
	}
	if maxConns > 0 {
		config.MaxConns = maxConns
	}
	if minConns >= 0 {
		config.MinConns = minConns
	}
	config.HealthCheckPeriod = 30 * time.Second

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("create database pool: %w", err)
	}

	wrapped := &Pool{pool: pool}
	if err := wrapped.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}

	return wrapped, nil
}

func (p *Pool) Ping(ctx context.Context) error {
	return p.pool.Ping(ctx)
}

func (p *Pool) Close() {
	p.pool.Close()
}

func (p *Pool) Raw() *pgxpool.Pool {
	return p.pool
}
