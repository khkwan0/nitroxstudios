# Nitrox Studios — company site

Astro marketing site for [nitroxstudios.com](https://nitroxstudios.com), plus a **fully self-hosted** CI/CD path that builds and deploys **on this host** when GitHub pushes to `master`. No GitHub Actions runners, no Vercel/Netlify/Cloudflare Pages.

## What’s here

| Path | Purpose |
|------|---------|
| `src/` | Astro pages & components |
| `public/` | Static assets, `robots.txt`, `sitemap.xml` |
| `nginx/` | Container nginx config + host proxy notes |
| `Dockerfile` / `docker-compose.yml` | Build Astro & serve with nginx in Docker |
| `ci/` | Lint → test → deploy pipeline + GitHub webhook listener |

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

## Self-hosted CI/CD (GitHub webhook → local build)

On push to `master`, GitHub POSTs to this host. A local listener verifies the HMAC secret, pulls `origin/master`, then runs `ci/pipeline.sh` (Docker image build + compose roll) on **this machine**.

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

After that, every `git push origin master` triggers a local rebuild.

```bash
# Manual deploy without waiting for a webhook
bash ci/pipeline.sh all

# Logs
journalctl --user -u nitroxstudios-www-webhook -f
tail -f ~/.local/share/nitroxstudios-www/deploy.log
```

Override the published port with `WWW_PORT=8080 bash ci/deploy.sh` if needed.
