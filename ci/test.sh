#!/usr/bin/env bash
# Test stage: build image and smoke-test HTTP responses locally via Docker.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IMAGE="nitroxstudios-www:ci-test"
NAME="nitroxstudios-www-ci-test-$$"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> test: docker build"
docker build -t "$IMAGE" .

echo "==> test: run container"
docker run -d --name "$NAME" -p 18099:80 "$IMAGE" >/dev/null

echo "==> test: wait for healthy HTTP"
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:18099/" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
  if [[ "$i" -eq 60 ]]; then
    echo "container did not become ready"
    docker logs "$NAME" || true
    exit 1
  fi
done

echo "==> test: HTTP status checks"
for path in / /robots.txt /sitemap.xml /favicon.svg; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:18099$path")"
  if [[ "$code" != "200" ]]; then
    echo " FAIL $path -> $code"
    exit 1
  fi
  echo "  OK  $path -> $code"
done

BODY="$(curl -fsS http://127.0.0.1:18099/)"
echo "$BODY" | grep -q 'Nitrox Studios' || { echo "FAIL home missing brand"; exit 1; }
echo "$BODY" | grep -q 'Bangkok Pool League' || { echo "FAIL home missing BPL product"; exit 1; }
echo "$BODY" | grep -q 'Expo' || { echo "FAIL home missing Expo mobile app mention"; exit 1; }
echo "$BODY" | grep -q 'apps.apple.com' || { echo "FAIL home missing App Store link"; exit 1; }
echo "$BODY" | grep -q 'OCR Core Impact' || { echo "FAIL home missing OCR product"; exit 1; }
echo "$BODY" | grep -q 'rel="canonical"' || { echo "FAIL home missing canonical"; exit 1; }
echo "  OK  home content assertions"

echo "test passed"
