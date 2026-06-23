FROM golang:1.26 AS build

WORKDIR /src
COPY . .
ENV GOFLAGS=-mod=vendor
RUN go test ./...
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/trip-api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/trip-migrate ./cmd/migrate

FROM alpine:3.20
RUN adduser -D -H trip
USER trip
COPY --from=build /out/trip-api /usr/local/bin/trip-api
COPY --from=build /out/trip-migrate /usr/local/bin/trip-migrate
COPY db/migrations /db/migrations
WORKDIR /
EXPOSE 8080
ENTRYPOINT ["trip-api"]
