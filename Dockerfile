# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry. Adapted from the fleet's static stack pack.
#
# Deviations from the pack, and why:
#   - `npm install` when no lockfile is committed; the pack assumes `npm ci`,
#     which fails outright without one.
#   - node:22, not the pack's node:20: Astro requires >=22.12 and Nuxt's build
#     crashes on 20 (trustedFunctions.difference is not a function).
#   - Angular emits dist/<project>/browser, not dist/.
#
# BASE_PATH is NOT baked in: it is per-agent and only known at run time, so the
# image serves at the host root under k8s and the agent's /direct/<id>:<port>
# run supplies its own prefix.

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
ARG BUILD_ID=""
ENV PORT=8080 BUILD_ID=$BUILD_ID
COPY --from=build /app/dist/angular/browser /usr/share/nginx/html
# /etc/nginx/templates does NOT exist in nginx-unprivileged:1.27-alpine, and
# the default uid 101 cannot create it under /etc/nginx — so this needs both a
# mkdir and root. The fleet's static stack pack writes straight to that path
# and fails with "can't create ...: nonexistent directory".
USER root
RUN mkdir -p /etc/nginx/templates && printf 'server {\n  listen ${PORT};\n  root /usr/share/nginx/html;\n  location / { try_files $uri $uri/ /index.html; }\n}\n' \
    > /etc/nginx/templates/default.conf.template
USER 101
EXPOSE 8080
