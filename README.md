# Nitrox Studios — company site

Astro marketing site for [nitroxstudios.com](https://nitroxstudios.com). GitHub Actions runs the CI checks. A push to `master` deploys on this host through the local webhook. No Vercel, Netlify, or Cloudflare Pages.

## What’s here

| Path | Purpose |
|------|---------|
| `src/` | Astro pages & components |
| `public/` | Static assets, `robots.txt`, `sitemap.xml` |
| `nginx/` | Container nginx config + host proxy notes |
| `Dockerfile` / `docker-compose.yml` | Build Astro & serve with nginx in Docker |
| `ci/` | Lint, test, and deploy scripts |
| `.github/workflows/ci.yml` | GitHub Actions CI: lint and Docker smoke test |

Default public URL: `https://nitroxstudios.com/`  
(AULA marketing site remains at `https://nitroxstudios.com/aula/` on a separate container.)

## Local preview

```bash
bun install
bun run dev
```

Or via Docker:

```bash
docker compose up -d --build
# open http://127.0.0.1:8099/
```

Pipeline stages:

```bash
bash ci/lint.sh
bash ci/test.sh      # needs Docker
bash ci/deploy.sh
# or
bash ci/pipeline.sh all
```

## GitHub Actions

Pull requests and pushes to `master` run lint and the Docker smoke test on a GitHub-hosted runner. The workflow does not deploy and does not use repository secrets. The **CI** job is the single status check: it passes only when lint and test both pass.

## On-host deploy

On push to `master`, GitHub POSTs to this host. A local listener verifies the HMAC secret, pulls `origin/master`, then runs `ci/pipeline.sh` (Docker image build and compose roll) on **this machine**.

That deploy does `git reset --hard origin/master` in this checkout. Commit local work before it runs.

### One-time setup on the deploy host

```bash
# 1) First build + start container on :8099
bash ci/pipeline.sh all

# 2) Webhook listener (user systemd) + secret file outside the repo
bash ci/install-webhook.sh

# 3) Patch host nginx (keeps /aula/ + Certbot) + linger
sudo bash ci/setup-host-nginx.sh
sudo loginctl enable-linger "$USER"
```

Then in GitHub → **Settings → Webhooks → Add webhook**:

| Field | Value |
|-------|--------|
| Payload URL | `https://nitroxstudios.com/hooks/github/nitroxstudios` |
| Content type | `application/json` |
| Secret | from `~/.config/nitroxstudios-www/webhook.env` (`grep WEBHOOK_SECRET …`) |
| Events | Just the **push** event |

After that, every `git push origin master` rebuilds the site here. GitHub Actions only reports the CI check.

```bash
# Manual deploy without waiting for a webhook
bash ci/pipeline.sh all

# Logs
journalctl --user -u nitroxstudios-www-webhook -f
tail -f ~/.local/share/nitroxstudios-www/deploy.log
```

Override the published port with `WWW_PORT=8080 bash ci/deploy.sh` if needed.
