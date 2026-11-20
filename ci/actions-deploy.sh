#!/usr/bin/env bash
# Forced command for the GitHub Actions deploy key.
# Pulls origin/master and rolls the Docker site on this host.
set -euo pipefail

export HOME="${HOME:-/home/ken}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

git fetch origin master
git reset --hard origin/master
bash "$ROOT/ci/deploy.sh"

if [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
  systemctl --user disable --now nitroxstudios-www-webhook.service || true
fi
