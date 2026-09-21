#!/usr/bin/env bash
#
# Angular production build for the fleet.
#
# The ingress forwards /direct/<agent>:<port> UNCHANGED, so the app has to be
# reachable at that path — but Angular emits a flat dist/ and `serve` has no
# prefix option. So: build with --base-href, then stage the output UNDER the
# prefix so the directory shape matches the URL.
#
# The SPA fallback is deliberately NOT written as a rewrite to
# "<prefix>/index.html": BASE_PATH contains a colon (agent:port) and `serve`
# runs destinations through path-to-regexp, which reads ":3000" as a route
# parameter and dies with `Expected "3000" to be a string`. Instead we drop a
# copy of index.html at the served root and rewrite to that colon-free path —
# it carries the right <base href>, so the SPA boots and routes itself.
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
[ -n "$prefix" ] && cp dist/angular/browser/index.html .fleet-www/index.html

printf '%s\n' '{ "rewrites": [ { "source": "**", "destination": "/index.html" } ] }' \
  > .fleet-www/serve.json

echo "fleet: staged Angular build at .fleet-www${prefix}/"
