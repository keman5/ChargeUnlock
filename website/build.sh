#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
/usr/bin/caffeinate -di -w $$ &
AWAKE_PID=$!
trap 'kill "$AWAKE_PID" 2>/dev/null || true' EXIT
if command -v go >/dev/null 2>&1; then go clean -cache -testcache; fi
rm -rf "$ROOT/../.artifacts"
python3 generate.py
node --test worker.test.mjs
python3 check.py
if [[ "${1:-}" == "-deploy" ]]; then
  if [[ -n "${WRANGLER_BIN:-}" ]]; then WRANGLER=(node "$WRANGLER_BIN"); else WRANGLER=(npx --yes --prefer-offline wrangler@4.152.0); fi
  if ! python3 -c 'import json; c=json.load(open("wrangler.json")); assert c.get("d1_databases")' 2>/dev/null; then
    "${WRANGLER[@]}" d1 create pluglit-feedback --binding DB --update-config
  fi
  "${WRANGLER[@]}" d1 execute pluglit-feedback --remote --file schema.sql
  "${WRANGLER[@]}" deploy
fi
