package database

import (
	"context"
	"errors"
)

type Pinger interface {
	Ping(ctx context.Context) error
	Close()
}

type DeferredPool struct {
	databaseURL string
}

func NewDeferredPool(databaseURL string) *DeferredPool {
	return &DeferredPool{databaseURL: databaseURL}
}

func (p *DeferredPool) Ping(ctx context.Context) error {
	if p.databaseURL == "" {
		return errors.New("DATABASE_URL is not configured")
	}

	// Stage 1 keeps the API skeleton dependency-light because the local
	// workspace currently lacks a Go toolchain. The pgx-backed pool replaces
	// this implementation when repository integration starts.
	return nil
}

func (p *DeferredPool) Close() {}
