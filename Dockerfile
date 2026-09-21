# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry. Adapted from the fleet's static stack pack.
#
# Deviations from the pack, and why:
#   - `npm install` when no lockfile is committed; the pack assumes `npm ci`,
#     which fails outright without one.
#   - Angular emits dist/<project>/browser, not dist/.
#
# BASE_PATH is NOT baked in: it is per-agent and only known at run time, so the
# image serves at the host root under k8s and the agent's /direct/<id>:<port>
# run supplies its own prefix.

FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
ARG BUILD_ID=""
ENV PORT=8080 BUILD_ID=$BUILD_ID
COPY --from=build /app/dist/angular/browser /usr/share/nginx/html
RUN printf 'server {\n  listen ${PORT};\n  root /usr/share/nginx/html;\n  location / { try_files $uri $uri/ /index.html; }\n}\n' \
    > /etc/nginx/templates/default.conf.template
EXPOSE 8080
