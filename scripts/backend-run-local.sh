#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v go >/dev/null 2>&1 && [[ -x /usr/local/go/bin/go ]]; then
    export PATH="/usr/local/go/bin:${PATH}"
fi
export DATABASE_URL="${DATABASE_URL:-postgres://trip:trip@localhost:5432/trip?sslmode=disable}"

cd "${ROOT_DIR}/backend"
go run ./cmd/api
