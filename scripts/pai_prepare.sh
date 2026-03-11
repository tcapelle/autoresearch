#!/usr/bin/env bash
set -euo pipefail

export REPO_DIR="${REPO_DIR:-/workspace/repo}"
export JOB_NAME="${JOB_NAME:-${POD_NAME:-autoresearch-prepare}}"
export RUN_DIR="${RUNS_DIR:-/mnt/autoresearch/jobs}/$JOB_NAME"
export AUTORESEARCH_GIT_SHA="${AUTORESEARCH_GIT_SHA:-$(cat /workspace/git-sha.txt)}"
export UV_LINK_MODE="${UV_LINK_MODE:-copy}"

mkdir -p "$RUN_DIR" "$AUTORESEARCH_CACHE_DIR" "$UV_CACHE_DIR"

{
  echo "job_name=$JOB_NAME"
  echo "git_repo=${GIT_REPO:-}"
  echo "git_branch=${GIT_BRANCH:-}"
  echo "git_sha=$AUTORESEARCH_GIT_SHA"
  echo "submitted_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$RUN_DIR/metadata.txt"

cd "$REPO_DIR"
if ! command -v uv >/dev/null 2>&1; then
  python -m pip install --no-input --quiet uv
fi

uv sync --frozen
uv run prepare.py --num-shards "${NUM_SHARDS:-10}" 2>&1 | tee "$RUN_DIR/prepare.log"
