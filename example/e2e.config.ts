import type { E2EConfig } from 'e2e';
import { web } from '@e2e-dev/web';
import { createOpenAICompatible } from '@ai-sdk/openai-compatible';
import { gateway } from 'ai';

// The model for agent steps, chosen explicitly by env (.env.example lists every name):
//   E2E_MODEL_PROVIDER=openai-compatible  E2E_MODEL_BASE_URL=<server>/v1  E2E_MODEL=<id>  [E2E_MODEL_API_KEY]
//     any OpenAI-compatible server: a local vLLM, llama.cpp, Ollama, LM Studio, ...
//   E2E_MODEL_PROVIDER=gateway  E2E_MODEL=<provider>/<model>  (+ AI_GATEWAY_API_KEY, read by `ai`)
// No E2E_MODEL: no model at all; agent steps fail with MODEL_UNAVAILABLE, deterministic steps run.
// Anything half-set fails here, naming what is missing.
function need(name: string): string {
  const value = process.env[name];
  if (value === undefined || value === '') throw new Error(`${name} is not set (E2E_MODEL is, so the model needs it)`);
  return value;
}

function model() {
  const id = process.env.E2E_MODEL;
  if (id === undefined || id === '') {
    const stray = ['E2E_MODEL_PROVIDER', 'E2E_MODEL_BASE_URL', 'E2E_MODEL_API_KEY'].filter((name) => (process.env[name] ?? '') !== '');
    if (stray.length > 0) throw new Error(`${stray.join(', ')} set but E2E_MODEL is not: set E2E_MODEL or unset them`);
    return undefined;
  }
  const provider = need('E2E_MODEL_PROVIDER');
  switch (provider) {
    case 'openai-compatible': {
      const apiKey = process.env.E2E_MODEL_API_KEY;
      return createOpenAICompatible({
        name: 'openai-compatible',
        baseURL: need('E2E_MODEL_BASE_URL'),
        ...(apiKey === undefined || apiKey === '' ? {} : { apiKey }),
      }).chatModel(id);
    }
    case 'gateway': {
      const ignored = ['E2E_MODEL_BASE_URL', 'E2E_MODEL_API_KEY'].filter((name) => (process.env[name] ?? '') !== '');
      if (ignored.length > 0) throw new Error(`${ignored.join(', ')} set, but the gateway provider does not read them: unset them`);
      return gateway(id);
    }
    default:
      throw new Error(`E2E_MODEL_PROVIDER must be openai-compatible or gateway, got ${JSON.stringify(provider)}`);
  }
}

const agentModel = model();

export default {
  ...(agentModel === undefined ? {} : { agents: { default: { model: agentModel } } }),
  targets: [
    {
      engine: web(),
      app: {
        // Port 0: e2e picks a free port per host, so parallel workers never collide.
        url: 'http://127.0.0.1:0',
        command: { executable: 'node', args: ['app/server.mjs'], env: { PORT: '{port}' }, log: '.e2e/app.log' },
      },
    },
  ],
} satisfies E2EConfig;
