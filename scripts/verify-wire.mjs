import { createServer } from 'node:http'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const [checkout, patchPath] = process.argv.slice(2)
if (checkout === undefined || patchPath === undefined) throw new Error('usage: verify-wire <checkout> <patch>')
const moduleUrl = path => pathToFileURL(resolve(checkout, path)).href
const { Context } = await import(moduleUrl('vendor/cordis/lib/index.js'))
const llm = await import(moduleUrl('packages/llm/llm/lib/index.js'))
const LlmRuntime = llm.default
const { BlockAssembler, ReasoningEffortId } = llm
const LlmPiAi = await import(moduleUrl('packages/llm/llm-pi-ai/lib/index.js'))
const require = createRequire(resolve(checkout, 'package.json'))
const yaml = require('js-yaml')
const rows = yaml.load(readFileSync(patchPath, 'utf8'))
const row = rows.find(candidate => candidate.id === 'llm-pi-ai')
if (row?.config === undefined) throw new Error('llm-pi-ai config missing')
const config = structuredClone(row.config)
const provider = config.providers['gpt-211api']
const requests = []
const events = [
  '{"choices":[{"delta":{"role":"assistant","content":""},"index":0,"finish_reason":null}]}',
  '{"choices":[{"delta":{"content":"ok"},"index":0,"finish_reason":null}]}',
  '{"choices":[{"delta":{},"index":0,"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1}}',
  '[DONE]',
]
const server = createServer((request, response) => {
  let body = ''
  request.on('data', chunk => { body += chunk.toString('utf8') })
  request.on('end', () => {
    requests.push(JSON.parse(body))
    response.writeHead(200, { 'content-type': 'text/event-stream' })
    for (const event of events) response.write('data: ' + event + '\n\n')
    response.end()
  })
})
await new Promise(resolveListen => server.listen(0, '127.0.0.1', resolveListen))
const address = server.address()
if (address === null || typeof address === 'string') throw new Error('mock server has no port')
provider.baseURL = 'http://127.0.0.1:' + address.port + '/v1'
provider.apiKeyEnv = 'GPT_211API_VERIFY_KEY'
process.env.GPT_211API_VERIFY_KEY = 'verification-only'
const levels = ['off', 'low', 'medium', 'high', 'xhigh', 'max']
const ctx = new Context()
try {
  await ctx.plugin(LlmRuntime)
  await ctx.plugin(LlmPiAi, config)
  for (const level of levels) {
    const assembler = new BlockAssembler()
    for await (const chunk of ctx.llm.stream({
      provider: 'gpt-211api',
      model: 'gpt-5.6-sol',
      reasoningEffort: ReasoningEffortId(level),
      messages: [],
    })) assembler.push(chunk)
  }
  if (requests.length !== levels.length) throw new Error('wire test request count mismatch')
  for (let index = 0; index < levels.length; index += 1) {
    const level = levels[index]
    const request = requests[index]
    if (level === 'off') {
      if ('reasoning_effort' in request) throw new Error('off sent reasoning_effort')
    } else if (request.reasoning_effort !== level) {
      throw new Error(level + ' dispatched as ' + String(request.reasoning_effort))
    }
  }
  console.log('wire: off omitted; low/medium/high/xhigh/max dispatched exactly')
} finally {
  delete process.env.GPT_211API_VERIFY_KEY
  server.closeAllConnections()
  await new Promise(resolveClose => server.close(resolveClose))
}
