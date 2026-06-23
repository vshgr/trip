#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/codex-push-main.sh "short change description"

What it does:
  1. Switches to main.
  2. Pulls the latest GitHub changes with rebase.
  3. Stops if Git reports conflicts so they can be fixed in code.
  4. Stages, commits, and pushes directly to main.

If conflicts happen:
  - Open the files marked by Git.
  - Choose the correct code between <<<<<<<, |||||||, =======, and >>>>>>>.
  - Remove all conflict markers.
  - Run: git add <fixed-files>
  - Run: git rebase --continue
  - Run this script again if there are still uncommitted changes.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

message="${1:-}"

if [[ -z "$message" ]]; then
  usage >&2
  exit 64
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Missing origin remote. Add it before publishing." >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "main" ]]; then
  echo "Switching from $current_branch to main"
  git switch main
fi

echo "Pulling latest main with rebase"
if ! git -c http.postBuffer=157286400 pull --rebase origin main; then
  cat >&2 <<'CONFLICT'

Git found conflicts while rebasing.
Fix the conflict markers in code, then run:

  git add <fixed-files>
  git rebase --continue

After the rebase finishes, rerun this script to commit and push remaining changes.
CONFLICT
  exit 1
fi

if git diff --quiet && git diff --cached --quiet && [[ -z "$(git status --porcelain)" ]]; then
  echo "No changes to publish."
  exit 0
fi

echo "Staging changes"
git add -A

echo "Committing"
git commit -m "$message"

echo "Pushing to main"
git -c http.postBuffer=157286400 push origin main

