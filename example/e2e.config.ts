import type { E2EConfig } from 'e2e';
import { web } from '@e2e-dev/web';
import { gateway } from 'ai';

const model = process.env.E2E_MODEL;

export default {
  // Agent steps need a model; without E2E_MODEL they fail with MODEL_UNAVAILABLE.
  ...(model ? { agents: { default: { model: gateway(model) } } } : {}),
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
