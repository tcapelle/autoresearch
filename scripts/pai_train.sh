#!/usr/bin/env bash
set -euo pipefail

export REPO_DIR="${REPO_DIR:-/workspace/repo}"
export JOB_NAME="${JOB_NAME:-${POD_NAME:-autoresearch-train}}"
export RUN_DIR="${RUNS_DIR:-/mnt/autoresearch/jobs}/$JOB_NAME"
export AUTORESEARCH_GIT_SHA="${AUTORESEARCH_GIT_SHA:-$(cat /workspace/git-sha.txt)}"
export UV_LINK_MODE="${UV_LINK_MODE:-copy}"
export HF_HOME="$RUN_DIR/hf-home"
export XDG_CACHE_HOME="$RUN_DIR/xdg-cache"
export TORCHINDUCTOR_CACHE_DIR="$RUN_DIR/torchinductor"
export TRITON_CACHE_DIR="$RUN_DIR/triton-cache"
export WANDB_DIR="$RUN_DIR/wandb"
export WANDB_RUN_NAME="${WANDB_RUN_NAME:-$JOB_NAME}"

mkdir -p \
  "$RUN_DIR" \
  "$AUTORESEARCH_CACHE_DIR" \
  "$UV_CACHE_DIR" \
  "$HF_HOME" \
  "$XDG_CACHE_HOME" \
  "$TORCHINDUCTOR_CACHE_DIR" \
  "$TRITON_CACHE_DIR" \
  "$WANDB_DIR"

{
  echo "job_name=$JOB_NAME"
  echo "git_repo=${GIT_REPO:-}"
  echo "git_branch=${GIT_BRANCH:-}"
  echo "git_sha=$AUTORESEARCH_GIT_SHA"
  echo "submitted_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "gpu=${GPU_COUNT:-1}"
  echo "cpu=${CPU_REQUEST:-}"
  echo "memory=${MEMORY_REQUEST:-}"
} > "$RUN_DIR/metadata.txt"

cd "$REPO_DIR"
if ! command -v uv >/dev/null 2>&1; then
  python -m pip install --no-input --quiet uv
fi

uv sync --frozen
uv run train.py 2>&1 | tee "$RUN_DIR/run.log"
grep '^val_bpb:\|^peak_vram_mb:\|^training_seconds:\|^total_seconds:\|^mfu_percent:\|^total_tokens_M:\|^num_steps:\|^num_params_M:\|^depth:' \
  "$RUN_DIR/run.log" | tee "$RUN_DIR/summary.txt" || true
