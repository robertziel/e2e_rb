# e2e_rb

[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Ruby >= 3.2](https://img.shields.io/badge/ruby-%3E%3D%203.2-red.svg)](e2e_rb.gemspec)
[![e2e ~> 0.23.1](https://img.shields.io/badge/e2e-~%3E%200.23.1-black.svg)](https://github.com/e2e-inc/e2e)

RSpec and Minitest tests on top of [e2e](https://github.com/e2e-inc/e2e), the agentic end-to-end
testing framework: `agent.act` / `agent.assert` plus e2e's auto-waiting locators and `expect`, from Ruby.

- **Ruby owns the test run**: RSpec / Minitest collection, hooks, filters and reporting; e2e owns the browser, the
  model, secrets and traces.
- **Agentic and deterministic steps in one test**: `agent.act("…")` next to `screen.get_by_role(…).click`.
- **e2e's own matchers**, as RSpec matchers and Minitest assertions (16 each), auto-waiting.
- **Any app** e2e can start, any [AI SDK](https://ai-sdk.dev) model, or none (deterministic steps need no model).
- **Process parallelism**: one bridge and one app port per worker.

```ruby
RSpec.describe "billing", type: :e2e do
  it "upgrades to Pro" do
    app.open("/settings/billing")
    agent.act("upgrade the workspace to the Pro plan")
    agent.assert("the invoice preview shows a prorated amount")
    expect(screen.get_by_role("status")).to contain_text("Pro")
  end
end
```

```ruby
class BillingTest < MyApp::Test          # your suite's own base class
  include E2eRb::Minitest

  def test_upgrade
    app.open("/settings/billing")
    screen.get_by_role("button", "Upgrade").click
    assert_contains_text screen.get_by_role("status"), "Pro"
  end
end
```

## Install

| | |
| --- | --- |
| Ruby | `gem "e2e_rb"` in the `Gemfile` (Ruby >= 3.2; RSpec 3.13, Minitest 5 or 6) |
| Node | `^22.22.3 \|\| >=24.8.0` (e2e's `engines.node`; the bridge refuses any other) |
| npm, in the project under test | `npm i -D e2e@~0.23.1 @e2e-dev/web` (the web engine) — e2e_rb `0.1.x` needs e2e `~> 0.23.1` |
| Browser | the Chromium build of the engine's `playwright-core`: `npx playwright-core install --with-deps chromium` |

The project under test is a normal e2e project: `package.json` with `e2e` and an engine, plus `e2e.config.ts`
(targets, how to start the app, agents/models). [`example/`](example/) is a complete one.

### Docker

Headless; no X server. Either start from Playwright's image (`mcr.microsoft.com/playwright:v<playwright-core
version>-noble`, Node and browsers included) and add Ruby, or start from Ruby and add Node + Chromium, as this
repo's [`Dockerfile`](Dockerfile) does:

```dockerfile
FROM node:24.21.0-bookworm-slim AS node
FROM ruby:3.4-slim-bookworm
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
# ... bundle install, then in the e2e project:
RUN npm ci && node_modules/.bin/playwright-core install --with-deps chromium
```

### CI without a model

Locators, actions and matchers are deterministic: they need no model and no network. With no model in
`e2e.config.ts`, an `agent.*` step fails at once with e2e's `MODEL_UNAVAILABLE` (an `E2eRb::ConfigurationError`);
everything else runs. This repo's own suite runs that way in a container with **no network at all**
(`network_mode: none`), so a gate built on deterministic steps cannot depend on a model or the internet.

### Telemetry

e2e's CLI sends anonymous usage data. In e2e 0.23.1 only `e2e run` and the CLI send it; the host API the
bridge uses (`openHost`) sends none. Set `E2E_TELEMETRY_DISABLED=1` (or `DO_NOT_TRACK=1`) anyway, e.g. in CI,
so a future e2e that adds it stays off. [e2e's telemetry docs](https://github.com/e2e-inc/e2e#telemetry).

## Settings

e2e's own config is `e2e.config.ts`. e2e_rb's settings are these env vars, or `E2eRb.configure { |c| ... }`
(before the first session):

| env | default | meaning |
| --- | --- | --- |
| `E2E_RB_PROJECT_DIR` | cwd | directory with `package.json`, `node_modules/e2e`, `e2e.config.ts` |
| `E2E_RB_CONFIG` | e2e's discovery | config file, relative to the project dir |
| `E2E_RB_TARGET` | e2e's rule (the only target) | target name |
| `E2E_RB_HEADED` | `0` | `1` runs the browser headed |
| `E2E_RB_NODE` | `node` | Node executable |
| `E2E_RB_TIMEOUT_MS` | config's `timeout` | per-test session deadline, a positive integer |
| `E2E_RB_VERBOSE` | `0` | `1` prints every e2e step |

Values are checked: a flag other than `0`/`1`, a timeout that is not a positive integer, a project dir without
`package.json`, or an `E2E_RB_*` name not in this table raises `E2eRb::ConfigurationError` naming it.

Also fails loudly on: an e2e version outside `E2eRb::E2E_REQUIREMENT`, a Node outside e2e's `engines.node`, a
protocol mismatch, a missing `node_modules/e2e`, an unknown fixture. e2e's own errors (e.g. `MODEL_UNAVAILABLE`)
arrive with their code.

### Models

The model is e2e's `agents` config, any [AI SDK](https://ai-sdk.dev) model. [`example/e2e.config.ts`](example/e2e.config.ts)
picks it from env, explicitly: `E2E_MODEL_PROVIDER=openai-compatible` + `E2E_MODEL_BASE_URL` + `E2E_MODEL` for any
OpenAI-compatible server (a local vLLM, llama.cpp, Ollama, ...), or `E2E_MODEL_PROVIDER=gateway` + `E2E_MODEL` +
`AI_GATEWAY_API_KEY`. A half-set combination fails, naming what is missing.

## Writing tests

### RSpec

```ruby
require "e2e_rb/rspec"   # tag groups with type: :e2e
```

### Minitest

```ruby
require "e2e_rb/minitest"
class BrowserTest < MyApp::Test
  include E2eRb::Minitest      # or: class BrowserTest < E2eRb::Minitest::Test
end
```

### Matchers

e2e's 16 locator/screen matchers, one table ([`lib/e2e_rb/matchers.rb`](lib/e2e_rb/matchers.rb)), all taking e2e's
options (e.g. `timeout: 500`):

| e2e | RSpec | Minitest |
| --- | --- | --- |
| `toBeVisible` `toBeHidden` `toBeAttached` | `be_visible` `be_hidden` `be_attached` | `assert_/refute_visible` `_hidden` `_attached` |
| `toBeEnabled` `toBeDisabled` `toBeChecked` | `be_enabled` `be_disabled` `be_checked` | `_enabled` `_disabled` `_checked` |
| `toBeSelected` `toBeExpanded` `toBeFocused` | `be_selected` `be_expanded` `be_focused` | `_selected` `_expanded` `_focused` |
| `toHaveText` `toContainText` `toHaveValue` | `have_text` `contain_text` `have_value` | `_text` `_contains_text` `_value` |
| `toHaveAttribute` `toHaveCount` | `have_attribute` `have_count` | `_attribute` `_count` |
| `toHaveAccessibleName` `toHaveScreenshot` | `have_accessible_name` `have_screenshot` | `_accessible_name` `_screenshot` |

Any matcher also as `e2e_expect(locator).to_have_text("x")` / `.not.to_be_visible`.

Text matchers take strings or Ruby regexps. Regexps are translated: `^`/`$` stay line anchors, `\A` `\z` `\Z` `\h`
work, `/m` is JavaScript's `s`; syntax JavaScript lacks (`\G`, `\K`, atomic groups, inline options, `&&`) raises
`ArgumentError`.

### Failures

A failed matcher or `agent.assert` is the framework's own failure (`ExpectationNotMetError` / `Minitest::Assertion`);
config and infrastructure problems are errors. Every failed e2e test names its `trace.md`, whatever failed.
The e2e host (the app, the engine) closes at the end of the suite; if that fails, the run fails with the reason.

## How it works

```
 Ruby process                                   Node process (one per Ruby process)
 ┌────────────────────────────┐  stdin  ─────►  ┌───────────────────────────────────┐
 │ RSpec / Minitest adapter    │                 │ bridge/server.mjs                 │
 │ E2eRb core: Proxy, Session, │  JSON-RPC 2.0   │  e2e/runner openHost()            │
 │ Expectation, Bridge         │  LSP framing    │   host.openSession() per test     │
 └────────────────────────────┘  ◄─────  fd 3   │  engine · model · secrets · trace │
                                                 └───────────────────────────────────┘
```

- Ruby owns collection, hooks, retries and reporting. e2e owns the engine, the model, secrets and traces.
- One e2e **session per test**: opened before each test, closed after it. Close-time failures
  (soft expectations, cleanup) fail the test.
- `screen.get_by_role("button", "greet").click` sends the whole call chain; Node re-applies it to the
  session's `screen`. Locators are immutable expressions in e2e, so nothing is held across the wire.
  Two locator proxies of the same expression are `==` and hash alike.
- Ruby names map to e2e names: `get_by_label` → `getByLabel`, `visible?` → `isVisible`,
  option keys `max_steps:` → `maxSteps` (`params:` keys stay as written). A member e2e does not have is a
  `NoMethodError`.
- Results cross as JSON; a result with no JSON form (a Buffer, a class instance) is refused with its type.
- A request abandoned by `Timeout` or `Interrupt` does not break the session: its late reply is skipped.
- Secrets never enter Ruby: `secret(:api_token)`, `credential(:admin, :password)` send only names.
- Protocol output goes to fd 3, so anything e2e or a browser prints to stdout cannot corrupt it.

## Parallelism

e2e allows one hosted session per process, so parallelize with processes (one Ruby process per test file,
parallel_tests, `rspec` per shard), not threads: `parallelize_me!` and any parallel run order raise. A forked
worker starts its own bridge. Use a port-0 app URL (`http://127.0.0.1:0` + `env: { PORT: '{port}' }`) so each
worker's app gets its own free port. CI runs 4 worker processes at once and checks each had its own bridge and
app port with all 4 sessions open together ([`scripts/parallel_workers.rb`](scripts/parallel_workers.rb)).

## Known limits

- **No replay cache**: e2e's public host API (`openHost`) gives hosted sessions no stable test identity or
  verdict, so `agent.act` calls the model on every run under e2e_rb. Deterministic steps are unaffected.
  Needs an upstream e2e change (`openSession({ testId, attempt })` + a verdict on close).
- No in-process app or transactional rollback: the app is its own process (started by e2e from
  `e2e.config.ts`); reset state in your own `setup` / `before` hooks.
- Not yet: `agent.extract` with a schema (Standard Schema has no wire form yet), custom `test.extend()`
  fixtures, cancelling a running step (a step runs to its own timeout).

## Develop

Everything runs in Docker:

```bash
cp .env.example .env
docker compose build
docker compose run --rm test       # scripts/ci/suite.sh: bridge tests, unit specs, RSpec + Minitest
                                   # examples, parallel workers, the built gem installed — no network
docker compose run --rm agentic    # agent steps against a real model (E2E_MODEL_*, .env.example)
scripts/ci/test.sh matrix          # what CI runs: Ruby 3.2 / 3.3 / 3.4 / 4.0, Minitest 6 and 5
```

## Contributing

Issues and pull requests are welcome: [CONTRIBUTING.md](CONTRIBUTING.md) (setup, tests, what a PR needs).
Security issues: [SECURITY.md](SECURITY.md), never a public issue. Changes per release: [CHANGELOG.md](CHANGELOG.md).

## License

[Apache-2.0](LICENSE). e2e itself is a separate project ([e2e-inc/e2e](https://github.com/e2e-inc/e2e), Apache-2.0).
