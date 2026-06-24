GO ?= $(shell if command -v go >/dev/null 2>&1; then command -v go; elif [ -x /usr/local/go/bin/go ]; then echo /usr/local/go/bin/go; elif [ -x ../.tools/go/bin/go ]; then echo ../.tools/go/bin/go; else echo go; fi)
export GOCACHE ?= $(abspath ../.cache/go-build)
export GOPATH ?= $(abspath ../.cache/gopath)
export DATABASE_URL ?= postgres://trip:trip@localhost:5432/trip?sslmode=disable

.PHONY: test run migrate docker-up docker-down env

test:
	$(GO) test ./...

run:
	$(GO) run ./cmd/api

migrate:
	$(GO) run ./cmd/migrate up

docker-up:
	docker compose up --build

docker-down:
	docker compose down

env:
	@echo "GO=$(GO)"
	@$(GO) version
	@echo "GOCACHE=$(GOCACHE)"
	@echo "GOPATH=$(GOPATH)"
	@echo "DATABASE_URL=$(DATABASE_URL)"
