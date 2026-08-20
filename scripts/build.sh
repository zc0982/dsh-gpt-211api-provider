#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CHECKOUT="${DSH_CHECKOUT:-}"
if [ -z "$CHECKOUT" ]; then
  for candidate in "$HOME/.dsh/deepseek-harness" "$HOME/deepseek-harness" "$HOME/dsh-harness"; do
    if [ -d "$candidate/packages" ]; then
      CHECKOUT="$candidate"
      break
    fi
  done
fi
if [ -z "$CHECKOUT" ] || [ ! -x "$CHECKOUT/node_modules/.bin/tsc" ]; then
  echo "build: cannot locate a built DeepSeek Harness checkout; set DSH_CHECKOUT" >&2
  exit 1
fi

rm -rf lib
"$CHECKOUT/node_modules/.bin/tsc" -p tsconfig.json
node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))"
node --input-type=module - "$CHECKOUT" <<'NODE'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
const checkout = process.argv[2]
const require = createRequire(resolve(checkout, 'package.json'))
const yaml = require('js-yaml')
const patch = yaml.load(readFileSync('cordis.patch.yml', 'utf8'))
if (!Array.isArray(patch) || patch.length !== 2) throw new Error('cordis.patch.yml must contain two row overrides')
const llm = patch.find(row => row?.id === 'llm-pi-ai')
const models = llm?.config?.providers?.['gpt-211api']?.models
if (!Array.isArray(models) || models.length !== 5) throw new Error('provider preset must declare five models')
const expected = ['off', 'low', 'medium', 'high', 'xhigh', 'max']
for (const model of models.slice(0, 3)) {
  const levels = Object.keys(model.reasoningEfforts ?? {})
  if (JSON.stringify(levels) !== JSON.stringify(expected)) {
    throw new Error(model.id + ' reasoning levels drifted: ' + levels.join(', '))
  }
}
NODE

echo "build: compiled bundle and validated provider preset"
