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
for path in / /software/ /robots.txt /sitemap-index.xml /og-image.png /favicon.svg; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:18099$path")"
  if [[ "$code" != "200" ]]; then
    echo " FAIL $path -> $code"
    exit 1
  fi
  echo "  OK  $path -> $code"
done

SITEMAP="$(curl -fsS http://127.0.0.1:18099/sitemap-index.xml)"
echo "$SITEMAP" | grep -q 'sitemap' || { echo "FAIL sitemap-index missing sitemap refs"; exit 1; }
echo "  OK  sitemap-index.xml content"

ROBOTS="$(curl -fsS http://127.0.0.1:18099/robots.txt)"
echo "$ROBOTS" | grep -q 'Sitemap: https://nitroxstudios.com/sitemap-index.xml' \
  || { echo "FAIL robots.txt missing Sitemap line"; exit 1; }
echo "  OK  robots.txt Sitemap line"

BODY="$(curl -fsS http://127.0.0.1:18099/)"
echo "$BODY" | grep -q 'Nitrox Studios' || { echo "FAIL home missing brand"; exit 1; }
echo "$BODY" | grep -q 'Systems built for massive' || { echo "FAIL home missing systems headline"; exit 1; }
echo "$BODY" | grep -q 'Millions' || { echo "FAIL home missing ad exchange scale"; exit 1; }
echo "$BODY" | grep -q '100,000' || { echo "FAIL home missing ad server scale"; exit 1; }
echo "$BODY" | grep -q 'fintech' || { echo "FAIL home missing fintech"; exit 1; }
echo "$BODY" | grep -q 'AI workflows' || { echo "FAIL home missing AI workflows"; exit 1; }
echo "$BODY" | grep -q 'rel="canonical"' || { echo "FAIL home missing canonical"; exit 1; }
echo "$BODY" | grep -q 'property="og:image"' || { echo "FAIL home missing og:image"; exit 1; }
echo "$BODY" | grep -q 'application/ld+json' || { echo "FAIL home missing JSON-LD"; exit 1; }
echo "  OK  home content assertions"

SOFTWARE="$(curl -fsS http://127.0.0.1:18099/software/)"
echo "$SOFTWARE" | grep -q 'Bangkok Pool League' || { echo "FAIL software missing BPL product"; exit 1; }
echo "$SOFTWARE" | grep -q 'Expo' || { echo "FAIL software missing Expo mobile app mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'MCP' || { echo "FAIL software missing BPL MCP mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'community forum' || { echo "FAIL software missing BPL forum mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'apps.apple.com' || { echo "FAIL software missing App Store link"; exit 1; }
echo "$SOFTWARE" | grep -q 'OCR Core Impact' || { echo "FAIL software missing OCR product"; exit 1; }
echo "$SOFTWARE" | grep -q 'shitsue' || { echo "FAIL software missing shitsue blog product"; exit 1; }
echo "$SOFTWARE" | grep -q 'shitsue.com' || { echo "FAIL software missing shitsue.com link"; exit 1; }
echo "$SOFTWARE" | grep -q 'UMPIRE' || { echo "FAIL software missing UMPIRE product"; exit 1; }
echo "$SOFTWARE" | grep -q 'WebSocket' || { echo "FAIL software missing UMPIRE WebSocket mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'MCP server' || { echo "FAIL software missing UMPIRE MCP server mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'AI agent harness' || { echo "FAIL software missing UMPIRE AI agent harness mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'Chrome &amp; Firefox' || { echo "FAIL software missing UMPIRE browser extensions mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'Agent tools' || { echo "FAIL software missing UMPIRE agent tools mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'Easy plugin system' || { echo "FAIL software missing UMPIRE plugin system mention"; exit 1; }
echo "$SOFTWARE" | grep -q 'docs/plugins.md' || { echo "FAIL software missing UMPIRE plugin guide link"; exit 1; }
echo "$SOFTWARE" | grep -q 'nitroxstudios.com/umpire' || { echo "FAIL software missing UMPIRE demo link"; exit 1; }
echo "$SOFTWARE" | grep -q 'github.com/khkwan0/umpire' || { echo "FAIL software missing UMPIRE GitHub link"; exit 1; }
echo "$SOFTWARE" | grep -q 'Meme Canvas' || { echo "FAIL software missing Meme Canvas product"; exit 1; }
echo "$SOFTWARE" | grep -q 'nitroxstudios.com/meme' || { echo "FAIL software missing meme product site link"; exit 1; }
echo "$SOFTWARE" | grep -q 'nitroxstudios.com/aula' || { echo "FAIL software missing AULA site link"; exit 1; }
if echo "$SOFTWARE" | grep -q 'github.com/khkwan0/ocr'; then
  echo "FAIL software still links private OCR repo"
  exit 1
fi
echo "  OK  software catalog assertions"

echo "test passed"
