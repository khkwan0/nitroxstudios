# Nitrox Studios — company site

Astro marketing site for [nitroxstudios.com](https://nitroxstudios.com). GitHub Actions lints and tests on push to `master`, then SSHs to this host to build and roll the Docker site. No Vercel, Netlify, or Cloudflare Pages.

## What’s here

| Path | Purpose |
|------|---------|
| `src/` | Astro pages & components |
| `public/` | Static assets, `robots.txt`, `sitemap.xml` |
| `nginx/` | Container nginx config + host proxy notes |
| `Dockerfile` / `docker-compose.yml` | Build Astro & serve with nginx in Docker |
| `ci/` | Lint, test, and deploy scripts |
| `.github/workflows/ci.yml` | GitHub Actions: lint, test, SSH deploy |

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

Push or a pull request runs lint and the Docker smoke test on a GitHub-hosted runner. A push to `master` then SSHs to this machine and runs `ci/actions-deploy.sh`, which pulls `origin/master` and rolls the container on port 8099.

That deploy does `git reset --hard origin/master` in this checkout. Commit local work before it runs.

### One-time setup on the deploy host

Host nginx still proxies the site to the container. If that is not in place yet:

```bash
bash ci/pipeline.sh all
sudo bash ci/setup-host-nginx.sh
sudo loginctl enable-linger "$USER"
```

Create the deploy key (it can only run `ci/actions-deploy.sh`):

```bash
bash ci/install-actions-deploy-key.sh
```

In GitHub → **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
|--------|--------|
| `DEPLOY_HOST` | `nitroxstudios.com` |
| `DEPLOY_USER` | the user printed by the install script |
| `DEPLOY_SSH_KEY` | contents of `~/.config/nitroxstudios-www/actions_deploy_ed25519` |

After that, `git push origin master` deploys. The first successful Actions deploy turns off the old webhook listener.

```bash
# Manual deploy without waiting for Actions
bash ci/deploy.sh
```

Override the published port with `WWW_PORT=8080 bash ci/deploy.sh` if needed.
