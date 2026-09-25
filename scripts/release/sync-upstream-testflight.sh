#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
UPSTREAM_REMOTE=origin
FORK_REMOTE=personal
BRANCH="${UPSTREAM_BRANCH:-cmp-rewrite}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: scripts/release/sync-upstream-testflight.sh [release options]

Fetches origin and personal, merges both remote branches into the clean local
branch, pushes the result to personal, then runs testflight.sh. Release options
such as --no-upload and --build-number are forwarded to testflight.sh.

Requires the local branch to track personal/<branch>; UPSTREAM_BRANCH defaults
to cmp-rewrite. Resolve and commit any merge conflicts, then rerun this script.
EOF
  exit 0
fi

CURRENT_BRANCH="$(git -C "$ROOT_DIR" branch --show-current)"
[[ -n "$CURRENT_BRANCH" ]] || { echo "Detached HEAD; check out $BRANCH first." >&2; exit 1; }
[[ "$CURRENT_BRANCH" == "$BRANCH" ]] || { echo "Check out $BRANCH before syncing (current: $CURRENT_BRANCH)." >&2; exit 1; }
[[ "$(git -C "$ROOT_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}')" == "$FORK_REMOTE/$BRANCH" ]] || {
  echo "Expected $BRANCH to track $FORK_REMOTE/$BRANCH." >&2
  exit 1
}
[[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] || {
  echo "Working tree must be clean; commit or stash changes before syncing." >&2
  exit 1
}
git -C "$ROOT_DIR" remote get-url "$UPSTREAM_REMOTE" >/dev/null
git -C "$ROOT_DIR" remote get-url "$FORK_REMOTE" >/dev/null

echo "==> Fetching upstream and personal fork"
git -C "$ROOT_DIR" fetch --prune "$UPSTREAM_REMOTE"
git -C "$ROOT_DIR" fetch --prune "$FORK_REMOTE"
for remote in "$UPSTREAM_REMOTE" "$FORK_REMOTE"; do
  git -C "$ROOT_DIR" show-ref --verify --quiet "refs/remotes/$remote/$BRANCH" || {
    echo "Remote branch $remote/$BRANCH was not found." >&2
    exit 1
  }
done

for remote in "$FORK_REMOTE" "$UPSTREAM_REMOTE"; do
  echo "==> Merging $remote/$BRANCH"
  if ! git -C "$ROOT_DIR" merge --no-edit "$remote/$BRANCH"; then
    echo "Merge stopped. Resolve conflicts, commit the merge, then rerun this script." >&2
    exit 1
  fi
done

echo "==> Pushing $BRANCH to the personal fork"
git -C "$ROOT_DIR" push "$FORK_REMOTE" "HEAD:$BRANCH"
exec "$ROOT_DIR/scripts/release/testflight.sh" "$@"
