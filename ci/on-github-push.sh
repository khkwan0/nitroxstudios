#!/usr/bin/env bash
# Called by github-webhook.py after a verified push to main.
# Pulls latest main and runs the local lint → test → deploy pipeline.
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/home/ken/dev/nitroxstudios.com}"
LOCK_FILE="${LOCK_FILE:-/tmp/nitroxstudios-www-deploy.lock}"
BRANCH="${WEBHOOK_BRANCH:-main}"
LOG_DIR="${LOG_DIR:-/home/ken/.local/share/nitroxstudios-www}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy.log"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "$(date -Is) deploy already running; skipping" | tee -a "$LOG_FILE"
  exit 0
fi

{
  echo "==== $(date -Is) deploy start ===="
  cd "$DEPLOY_ROOT"
  git fetch origin "$BRANCH"
  git reset --hard "origin/$BRANCH"
  bash "$DEPLOY_ROOT/ci/pipeline.sh" all
  echo "==== $(date -Is) deploy done ===="
} 2>&1 | tee -a "$LOG_FILE"
