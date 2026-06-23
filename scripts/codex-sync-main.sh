#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "main" ]]; then
  echo "Switching from $current_branch to main"
  git switch main
fi

echo "Syncing main from GitHub"
git -c http.postBuffer=157286400 pull --rebase origin main

