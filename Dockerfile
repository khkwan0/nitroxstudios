# Multi-stage: Astro build (Bun) → nginx static serve
FROM oven/bun:1.3-alpine AS build
WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY astro.config.mjs tsconfig.json ./
COPY public ./public
COPY src ./src

RUN bun run build \
 && test -f dist/index.html

FROM nginx:1.27-alpine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/ /usr/share/nginx/html/

RUN test -f /usr/share/nginx/html/index.html \
 && test -f /usr/share/nginx/html/robots.txt \
 && test -f /usr/share/nginx/html/sitemap.xml \
 && test -f /usr/share/nginx/html/favicon.svg

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
