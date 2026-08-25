#!/usr/bin/env bash
# Patch host nginx so nitroxstudios.com root proxies to Docker :8099,
# and the GitHub webhook path proxies to the local listener :9002.
# Preserves existing /aula/ → :8098 and aula webhook → :9001 + Certbot SSL.
# Usage: sudo bash ci/setup-host-nginx.sh
set -euo pipefail

DOMAIN="${DOMAIN:-nitroxstudios.com}"
WWW_PORT="${WWW_PORT:-8099}"
WEBHOOK_PORT="${WEBHOOK_PORT:-9002}"
CONF="${NGINX_CONF:-/etc/nginx/sites-available/${DOMAIN}.conf}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

if [[ ! -f "$CONF" ]]; then
  echo "Missing $CONF"
  exit 1
fi

echo "==> ensure Docker site is up on :${WWW_PORT}"
if ! curl -fsS "http://127.0.0.1:${WWW_PORT}/" >/dev/null; then
  echo "Container not responding on :${WWW_PORT}/. Start it first:"
  echo "  bash $(cd "$(dirname "$0")/.." && pwd)/ci/deploy.sh"
  exit 1
fi

BACKUP="${CONF}.bak.nitrox-$(date +%Y%m%d%H%M%S)"
cp -a "$CONF" "$BACKUP"
echo "==> backed up $CONF → $BACKUP"

python3 - "$CONF" "$WWW_PORT" "$WEBHOOK_PORT" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
www_port = sys.argv[2]
webhook_port = sys.argv[3]
text = path.read_text()

webhook_block = f"""
    location ^~ /hooks/github/nitroxstudios {{
        proxy_pass http://127.0.0.1:{webhook_port}/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Hub-Signature-256 $http_x_hub_signature_256;
        proxy_set_header X-GitHub-Event $http_x_github_event;
        proxy_set_header X-GitHub-Delivery $http_x_github_delivery;
        proxy_read_timeout 30s;
    }}
"""

root_block = f"""
    location / {{
        proxy_pass http://127.0.0.1:{www_port};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'sha256-tnk0w6Uzwx1FGj33NRTmV/nTLRFabneUyghOlmXoX+I='; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'self'; object-src 'none'; upgrade-insecure-requests" always;
    }}
"""

# Drop prior nitroxstudios main-site blocks if re-running
text = re.sub(
    r"\n\s*location \^~ /hooks/github/nitroxstudios\s*\{.*?\n\s*\}\n",
    "\n",
    text,
    flags=re.S,
)
text = re.sub(
    r"\n\s*# Nitrox Studios main site.*?(?=\n\s*location |\n\s*listen |\n\})",
    "\n",
    text,
    flags=re.S,
)
# Remove a bare location / that proxies to 8099 (our previous install)
text = re.sub(
    r"\n\s*location /\s*\{[^}]*127\.0\.0\.1:8099[^}]*\}\n",
    "\n",
    text,
    flags=re.S,
)

marker = "location ^~ /hooks/github/aula-www"
if marker in text:
    text = text.replace(
        marker,
        webhook_block.strip() + "\n\n    " + marker,
        1,
    )
else:
    # Insert webhook after acme-challenge block
    acme = "location /.well-known/acme-challenge/"
    idx = text.find(acme)
    if idx == -1:
        raise SystemExit("could not find insertion point for webhook location")
    # find end of that location block
    end = text.find("}", idx)
    end = text.find("\n", end) + 1
    text = text[:end] + "\n" + webhook_block + text[end:]

# Ensure /aula locations exist before location /
if not re.search(r"location\s+/aula", text):
    raise SystemExit("expected /aula location in host nginx; aborting to avoid breaking AULA")

# Insert location / just before the first `listen` with ssl, or before closing of first server
if re.search(r"location\s+/\s*\{[^}]*127\.0\.0\.1:" + re.escape(www_port), text, flags=re.S):
    print("    root proxy already present")
else:
    listen_ssl = re.search(r"\n\s*listen\s+.*443", text)
    if not listen_ssl:
        raise SystemExit("could not find SSL listen directive to insert location / before")
    insert_at = listen_ssl.start()
    text = (
        text[:insert_at]
        + "\n    # Nitrox Studios main site (Astro) → Docker :"
        + www_port
        + "\n"
        + root_block
        + text[insert_at:]
    )

path.write_text(text)
print(f"patched {path}")
PY

nginx -t
systemctl reload nginx

echo "==> verify"
curl -fsS "https://${DOMAIN}/" | grep -q 'Nitrox Studios' \
  && echo "  OK  https://${DOMAIN}/ brands Nitrox Studios" \
  || echo "  WARN https://${DOMAIN}/ content check failed"
curl -s -o /dev/null -w "  /aula/ -> %{http_code}\n" "https://${DOMAIN}/aula/"
curl -s -o /dev/null -w "  /      -> %{http_code}\n" "https://${DOMAIN}/"
echo "Done. https://${DOMAIN}/ → 127.0.0.1:${WWW_PORT}"
