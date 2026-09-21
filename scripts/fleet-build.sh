#!/usr/bin/env bash
#
# Angular production build for the fleet.
#
# The ingress forwards /direct/<agent>:<port> UNCHANGED, so the app has to be
# reachable at that path — but Angular emits a flat dist/ and `serve` has no
# prefix option. So: build with --base-href, then stage the output UNDER the
# prefix and hand `serve` a directory whose shape matches the URL.
#
# Empty/unset BASE_PATH => stage at the root (standalone mode).
set -euo pipefail

raw="${BASE_PATH:-}"
base="$(printf '%s' "$raw" | sed -E 's#^/+##; s#/+$##')"
prefix=""
[ -n "$base" ] && prefix="/$base"

npm run build -- --base-href "${prefix}/"

rm -rf .fleet-www
mkdir -p ".fleet-www${prefix}"
cp -r dist/angular/browser/. ".fleet-www${prefix}/"

# SPA fallback has to point at the index INSIDE the prefix, or a deep-link
# refresh 404s.
cat > .fleet-www/serve.json <<JSON
{ "rewrites": [ { "source": "**", "destination": "${prefix}/index.html" } ] }
JSON

echo "fleet: staged Angular build at .fleet-www${prefix}/"
