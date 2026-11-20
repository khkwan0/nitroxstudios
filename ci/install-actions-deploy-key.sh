#!/usr/bin/env bash
# One-time: create an SSH key GitHub Actions uses to deploy on this host.
# The key can only run ci/actions-deploy.sh.
# Usage: bash ci/install-actions-deploy-key.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nitroxstudios-www"
KEY="$CONFIG_DIR/actions_deploy_ed25519"
AUTH="$HOME/.ssh/authorized_keys"
MARKER="nitroxstudios-www-actions-deploy"
DEPLOY_HOST="${DEPLOY_HOST:-nitroxstudios.com}"

mkdir -p "$CONFIG_DIR" "$HOME/.ssh"
chmod 700 "$CONFIG_DIR" "$HOME/.ssh"

if [[ ! -f "$KEY" ]]; then
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "$MARKER"
  echo "==> created $KEY"
else
  echo "==> reusing $KEY"
fi
chmod 600 "$KEY"

PUB="$(ssh-keygen -y -f "$KEY")"
FORCED="command=\"${REPO_ROOT}/ci/actions-deploy.sh\",restrict"
LINE="${FORCED} ${PUB} ${MARKER}"

touch "$AUTH"
chmod 600 "$AUTH"
grep -v "$MARKER" "$AUTH" > "${AUTH}.tmp" || true
printf '%s\n' "$LINE" >> "${AUTH}.tmp"
mv "${AUTH}.tmp" "$AUTH"
chmod 600 "$AUTH"

echo
echo "Add these repository secrets on khkwan0/nitroxstudios"
echo "(Settings → Secrets and variables → Actions):"
echo
echo "  DEPLOY_HOST=$DEPLOY_HOST"
echo "  DEPLOY_USER=$(id -un)"
echo "  DEPLOY_SSH_KEY=<contents of $KEY>"
echo
echo "Private key path: $KEY"
echo "After the secrets are saved, git push origin master runs lint, test, and deploy."
