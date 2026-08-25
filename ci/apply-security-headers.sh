#!/usr/bin/env bash
# Add HSTS + CSP to the public host nginx for nitroxstudios.com.
# Usage: sudo bash ci/apply-security-headers.sh
set -euo pipefail

CONF="${NGINX_CONF:-/etc/nginx/sites-available/nitroxstudios.com.conf}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

if [[ ! -f "$CONF" ]]; then
  echo "Missing $CONF"
  exit 1
fi

BACKUP="${CONF}.bak.headers-$(date +%Y%m%d%H%M%S)"
cp -a "$CONF" "$BACKUP"
echo "==> backed up $CONF → $BACKUP"

python3 - "$CONF" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()

HSTS = 'add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;'
CSP = (
    'add_header Content-Security-Policy "default-src \'self\'; '
    # Inline Astro module scripts need a hash; external /_astro/*.js uses 'self'.
    # Hash covers the currently-deployed reveal script until the next image roll.
    'script-src \'self\' \'sha256-tnk0w6Uzwx1FGj33NRTmV/nTLRFabneUyghOlmXoX+I=\'; '
    'style-src \'self\' \'unsafe-inline\' https://fonts.googleapis.com; '
    'font-src \'self\' https://fonts.gstatic.com; '
    'img-src \'self\' data:; connect-src \'self\'; base-uri \'self\'; form-action \'self\'; '
    'frame-ancestors \'self\'; object-src \'none\'; upgrade-insecure-requests" always;'
)

# Strip prior copies so re-runs are idempotent
text = re.sub(
    r'\n[ \t]*add_header Strict-Transport-Security "[^"]*" always;\n?',
    "\n",
    text,
)
text = re.sub(
    r'\n[ \t]*add_header Content-Security-Policy "[^"]*" always;\n?',
    "\n",
    text,
)

# HSTS on the HTTPS server (domain-wide; inherited by locations without add_header)
m = re.search(
    r"(server_name\s+nitroxstudios\.com\s+www\.nitroxstudios\.com;\n)",
    text,
)
if not m:
    raise SystemExit("HTTPS server_name not found")
text = text[: m.end()] + f"\n    {HSTS}\n" + text[m.end() :]

# CSP (+ HSTS again) on location / — nginx drops inherited add_header once any
# add_header exists in the location.
loc = re.search(
    r"(location\s+/\s*\{[^}]*127\.0\.0\.1:8099[^}]*)(\})",
    text,
    flags=re.S,
)
if not loc:
    raise SystemExit("location / → :8099 not found")
text = (
    text[: loc.start(1)]
    + loc.group(1).rstrip()
    + f"\n        {HSTS}\n        {CSP}\n    "
    + loc.group(2)
    + text[loc.end() :]
)

path.write_text(text)
print(f"patched {path}")
PY

nginx -t
systemctl reload nginx

echo "==> verify"
curl -sI "https://nitroxstudios.com/" | grep -Ei 'HTTP/|strict-transport|content-security|x-content-type|x-frame|referrer-policy|permissions-policy'
echo "Done."
