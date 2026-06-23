.PHONY: test run docker-up

test:
	go test ./...

run:
	go run ./cmd/api

docker-up:
	docker compose up --build
