FROM golang:1.26-alpine AS build

WORKDIR /src
COPY go.mod ./
COPY . .
RUN go test ./...
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/trip-api ./cmd/api

FROM alpine:3.20
RUN adduser -D -H trip
USER trip
COPY --from=build /out/trip-api /usr/local/bin/trip-api
EXPOSE 8080
ENTRYPOINT ["trip-api"]
