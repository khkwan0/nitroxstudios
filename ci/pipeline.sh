#!/usr/bin/env bash
# Lint → test → deploy.
# GitHub Actions runs lint and test on ubuntu-latest, then SSHs here for deploy.
# You can still run a stage by hand on this host.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STAGE="${1:-all}"

run_lint() { bash "$ROOT/ci/lint.sh"; }
run_test() { bash "$ROOT/ci/test.sh"; }
run_deploy() { bash "$ROOT/ci/deploy.sh"; }

case "$STAGE" in
  lint) run_lint ;;
  test) run_test ;;
  deploy) run_deploy ;;
  all)
    run_lint
    run_test
    run_deploy
    ;;
  *)
    echo "usage: $0 [all|lint|test|deploy]"
    exit 2
    ;;
esac
