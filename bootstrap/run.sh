#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
nix-shell -p nodejs_22 --run "npm install --silent && npx tsx src/index.tsx"
