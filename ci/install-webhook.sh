#!/usr/bin/env bash
# One-time: secret env + user systemd unit for the GitHub webhook listener.
# Usage: bash ci/install-webhook.sh
# Does not require sudo. Host nginx still needs: sudo bash ci/setup-host-nginx.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CI_DIR="$REPO_ROOT/ci"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nitroxstudios-www"
ENV_FILE="$CONFIG_DIR/webhook.env"
UNIT_SRC="$CI_DIR/nitroxstudios-www-webhook.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_DST="$UNIT_DIR/nitroxstudios-www-webhook.service"
DOMAIN="${DOMAIN:-nitroxstudios.com}"
HOOK_PATH="/hooks/github/nitroxstudios"

chmod +x "$CI_DIR"/github-webhook.py "$CI_DIR"/on-github-push.sh "$CI_DIR"/pipeline.sh \
  "$CI_DIR"/lint.sh "$CI_DIR"/test.sh "$CI_DIR"/deploy.sh "$CI_DIR"/install-webhook.sh \
  "$CI_DIR"/setup-host-nginx.sh

mkdir -p "$CONFIG_DIR" "$UNIT_DIR"
chmod 700 "$CONFIG_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  SECRET="$(openssl rand -hex 32)"
  cat > "$ENV_FILE" <<EOF
WEBHOOK_SECRET=$SECRET
WEBHOOK_HOST=127.0.0.1
WEBHOOK_PORT=9002
DEPLOY_ROOT=$REPO_ROOT
DEPLOY_SCRIPT=$CI_DIR/on-github-push.sh
WEBHOOK_BRANCH_REF=refs/heads/master
WEBHOOK_BRANCH=master
EOF
  chmod 600 "$ENV_FILE"
  echo "==> created $ENV_FILE"
else
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  SECRET="${WEBHOOK_SECRET:?WEBHOOK_SECRET missing in $ENV_FILE}"
  echo "==> reusing $ENV_FILE"
fi

sed \
  -e "s|%h/dev/nitroxstudios.com|$REPO_ROOT|g" \
  -e "s|WorkingDirectory=.*|WorkingDirectory=$CI_DIR|" \
  -e "s|EnvironmentFile=.*|EnvironmentFile=$ENV_FILE|" \
  -e "s|ExecStart=.*|ExecStart=/usr/bin/python3 $CI_DIR/github-webhook.py|" \
  "$UNIT_SRC" > "$UNIT_DST"

systemctl --user daemon-reload
systemctl --user enable --now nitroxstudios-www-webhook.service
systemctl --user restart nitroxstudios-www-webhook.service

sleep 0.5
if curl -fsS "http://127.0.0.1:9002/healthz" >/dev/null; then
  echo "==> webhook listener healthy on 127.0.0.1:9002"
else
  echo "ERROR: webhook listener not responding"
  systemctl --user status nitroxstudios-www-webhook.service --no-pager || true
  exit 1
fi

echo
echo "Webhook install complete (user systemd)."
echo
echo "Still needed on this host (run in a terminal with sudo):"
echo "  sudo bash $REPO_ROOT/ci/setup-host-nginx.sh"
echo "  sudo loginctl enable-linger $USER"
echo
echo "Create a GitHub webhook (Settings → Webhooks → Add webhook):"
echo "  Payload URL:  https://${DOMAIN}${HOOK_PATH}"
echo "  Content type: application/json"
echo "  Secret:       (from $ENV_FILE — WEBHOOK_SECRET=...)"
echo "  Events:       Just the push event"
echo "  Active:       checked"
echo
echo "  grep WEBHOOK_SECRET $ENV_FILE"
echo
echo "Deploy logs:  ~/.local/share/nitroxstudios-www/deploy.log"
echo "Service logs: journalctl --user -u nitroxstudios-www-webhook -f"
