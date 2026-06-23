#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/codex-publish-mr.sh "short-change-description" [base-branch]

What it does:
  1. Verifies this is a git repository with an origin remote.
  2. Creates a fresh codex/<slug> branch from the current branch.
  3. Stages the current working tree, commits it, and pushes the branch.
  4. Opens a draft GitHub PR when GitHub CLI is installed and authenticated.
     If gh is unavailable, prints the GitHub compare URL instead.

Run this when the user asks Codex to "залить МР".
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

description="${1:-}"
base_branch="${2:-main}"

if [[ -z "$description" ]]; then
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

if git diff --quiet && git diff --cached --quiet && [[ -z "$(git status --porcelain)" ]]; then
  echo "No changes to publish." >&2
  exit 1
fi

slug="$(printf '%s' "$description" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"

if [[ -z "$slug" ]]; then
  slug="update"
fi

timestamp="$(date +%Y%m%d%H%M%S)"
branch="codex/${slug}-${timestamp}"

echo "Creating branch: $branch"
git switch -c "$branch"

echo "Staging changes"
git add -A

echo "Committing"
git commit -m "$description"

echo "Pushing"
git -c http.postBuffer=157286400 push -u origin "$branch"

remote_url="$(git remote get-url origin)"
repo_path="$remote_url"
repo_path="${repo_path#git@github.com:}"
repo_path="${repo_path#https://github.com/}"
repo_path="${repo_path%.git}"

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo "Opening draft PR"
    gh pr create \
      --draft \
      --base "$base_branch" \
      --head "$branch" \
      --title "[codex] $description" \
      --body "## Summary
- $description

## Validation
- Not run by script; Codex should run relevant checks before publishing when available."
  else
    echo "gh is installed but not authenticated. Run: gh auth login" >&2
    echo "Compare URL: https://github.com/${repo_path}/compare/${base_branch}...${branch}?quick_pull=1"
  fi
else
  echo "gh is not installed; open the PR manually:"
  echo "https://github.com/${repo_path}/compare/${base_branch}...${branch}?quick_pull=1"
fi
