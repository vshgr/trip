#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/codex-start-feature.sh "short task name"

What it does:
  1. Shows the current branch.
  2. Stops for confirmation if there are uncommitted or unpushed changes.
  3. Switches to main.
  4. Pulls the latest origin/main with fast-forward only.
  5. Creates a new codex/* feature branch.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

task_name="${1:-}"
if [[ -z "$task_name" ]]; then
  usage >&2
  exit 64
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Missing origin remote. Add it before starting a feature branch." >&2
  exit 1
fi

slug="$(printf '%s' "$task_name" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"

if [[ -z "$slug" ]]; then
  slug="feature"
fi

branch="codex/$slug"
current_branch="$(git branch --show-current)"

echo "Current branch: $current_branch"
git status --short --branch

dirty_status="$(git status --porcelain)"
ahead_count="0"

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  ahead_count="$(git rev-list --count '@{u}..HEAD')"
else
  current_commit="$(git rev-parse HEAD)"
  main_commit="$(git rev-parse main 2>/dev/null || true)"
  if [[ "$current_branch" != "main" && -n "$main_commit" && "$current_commit" != "$main_commit" ]]; then
    ahead_count="unknown"
  fi
fi

if [[ -n "$dirty_status" || "$ahead_count" != "0" ]]; then
  cat <<EOF

This branch has uncommitted or unpushed work.

Choose what to do:
  c - commit and push it yourself first, then rerun this script
  k - keep working on the current branch
  n - start a new branch anyway
EOF

  read -r -p "Your choice [c/k/n]: " choice
  case "$choice" in
    c|C)
      echo "Stopping so you can commit and push the current work."
      exit 2
      ;;
    k|K)
      echo "Keeping current branch: $current_branch"
      exit 0
      ;;
    n|N)
      echo "Starting a new branch anyway."
      ;;
    *)
      echo "Unknown choice. Stopping without changes." >&2
      exit 64
      ;;
  esac
fi

if [[ "$current_branch" != "main" ]]; then
  echo "Switching to main"
  git switch main
fi

echo "Pulling latest origin/main"
git pull --ff-only origin main

if git show-ref --verify --quiet "refs/heads/$branch"; then
  suffix="$(date +%Y%m%d%H%M%S)"
  branch="$branch-$suffix"
fi

echo "Creating branch: $branch"
git switch -c "$branch"
