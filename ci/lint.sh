#!/usr/bin/env bash
# Lint stage: structural + SEO checks (no third-party SaaS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

ok() { printf '  OK  %s\n' "$1"; }
bad() { printf ' FAIL %s\n' "$1"; FAIL=1; }

echo "==> lint: required source files"
for f in package.json bun.lock astro.config.mjs Dockerfile docker-compose.yml \
         src/pages/index.astro src/layouts/BaseLayout.astro \
         src/components/Hero.astro src/components/Products.astro \
         nginx/default.conf \
         public/robots.txt public/og-image.png public/favicon.svg; do
  if [[ -f "$ROOT/$f" ]]; then ok "$f"; else bad "missing $f"; fi
done

echo "==> lint: SEO markers in BaseLayout.astro"
LAYOUT="$ROOT/src/layouts/BaseLayout.astro"
for needle in \
  '<title>' \
  'name="description"' \
  'rel="canonical"' \
  'property="og:title"' \
  'property="og:image"' \
  'application/ld+json' \
  'name="twitter:card"' \
  'name="robots"' \
  'sitemap-index.xml' \
  'Nitrox Studios'; do
  if grep -q "$needle" "$LAYOUT"; then ok "layout has $needle"; else bad "layout missing $needle"; fi
done

echo "==> lint: Astro site + sitemap integration"
if grep -q 'site:' "$ROOT/astro.config.mjs" && grep -q '@astrojs/sitemap' "$ROOT/astro.config.mjs"; then
  ok "astro.config has site + sitemap"
else
  bad "astro.config missing site or sitemap integration"
fi

echo "==> lint: brand on index"
if grep -q 'Nitrox Studios' "$ROOT/src/pages/index.astro" \
  || grep -q 'Nitrox Studios' "$ROOT/src/components/Hero.astro"; then
  ok "index/hero brands Nitrox Studios"
else
  bad "missing Nitrox Studios brand on home"
fi

echo "==> lint: robots + sitemap consistency"
if grep -q 'Sitemap:' "$ROOT/public/robots.txt"; then ok "robots.txt declares Sitemap"; else bad "robots.txt missing Sitemap"; fi
if grep -q 'sitemap-index.xml' "$ROOT/public/robots.txt"; then ok "robots points at sitemap-index.xml"; else bad "robots missing sitemap-index.xml"; fi

echo "==> lint: no accidental secrets"
if grep -RInE '(api[_-]?key|secret|password)\s*[:=]' \
  "$ROOT/src" "$ROOT/public" \
  --include='*.astro' --include='*.html' --include='*.js' --include='*.css' --include='*.ts' \
  >/dev/null 2>&1; then
  bad "possible secret pattern in source/public"
else
  ok "no obvious secrets in source/public"
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "lint failed"
  exit 1
fi
echo "lint passed"
