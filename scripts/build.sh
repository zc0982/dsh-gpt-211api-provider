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

(
  cd "$CHECKOUT"
  node --experimental-strip-types --input-type=module - "$ROOT/cordis.patch.yml" <<'NODE'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolveProfiles } from './packages/llm/llm-pi-ai/src/config.ts'
import { getSupportedThinkingLevels } from './packages/llm/llm-pi-ai/node_modules/@earendil-works/pi-ai/dist/index.js'
const require = createRequire(import.meta.url)
const yaml = require('js-yaml')
const rows = yaml.load(readFileSync(process.argv[2], 'utf8'))
const providerRow = rows.find(row => row.id === 'llm-pi-ai')
const profile = resolveProfiles(providerRow.config.providers).get('gpt-211api')
if (profile === undefined) throw new Error('gpt-211api route did not resolve')
const expected = ['off', 'low', 'medium', 'high', 'xhigh', 'max']
for (const model of profile.piProvider.getModels().slice(0, 3)) {
  const actual = getSupportedThinkingLevels(model)
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(model.id + ' resolved levels drifted: ' + actual.join(', '))
  }
  if (model.compat?.supportsReasoningEffort !== true) {
    throw new Error(model.id + ' does not force reasoning_effort dispatch')
  }
}
const defaultRow = rows.find(row => row.id === 'agent-default-model')
const defaultKeys = Object.keys(defaultRow?.config ?? {}).sort()
if (JSON.stringify(defaultKeys) !== JSON.stringify(['model', 'provider'])) {
  throw new Error('agent-default-model config has unsupported fields: ' + defaultKeys.join(', '))
}
NODE

  node "$ROOT/scripts/verify-wire.mjs" "$CHECKOUT" "$ROOT/cordis.patch.yml"
)

echo "build: compiled bundle and validated six-level DSH wire dispatch"
