# e2e_rb

RSpec and Minitest tests on top of [e2e](https://e2e.com), the agentic end-to-end testing
framework: `agent.act` / `agent.assert` plus e2e's auto-waiting locators and `expect`, from Ruby.

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
class BillingTest < E2eRb::Minitest::Test
  def test_upgrade
    app.open("/settings/billing")
    agent.act("upgrade the workspace to the Pro plan")
    assert_contains_text screen.get_by_role("status"), "Pro"
  end
end
```

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
- Ruby names map to e2e names: `get_by_label` → `getByLabel`, `visible?` → `isVisible`,
  option keys `max_steps:` → `maxSteps` (`params:` keys stay as written).
- Matchers run e2e's own `expect` in Node (auto-waiting, e2e's failure messages).
  A failed expect or `agent.assert` is a framework **failure** (`ExpectationNotMetError` /
  `Minitest::Assertion`) with the `trace.md` path; config and infrastructure problems are errors.
- Secrets never enter Ruby: `secret(:api_token)`, `credential(:admin, :password)` send only names.
- Protocol output goes to fd 3, so anything e2e or a browser prints to stdout cannot corrupt it.

## Setup

The project under test is a normal e2e project: `package.json` with `e2e` and an engine,
plus `e2e.config.ts` (targets, app command, agents/models). e2e_rb adds no config of its own.

| env | default | meaning |
| --- | --- | --- |
| `E2E_RB_PROJECT_DIR` | cwd | directory with `node_modules/e2e` and `e2e.config.ts` |
| `E2E_RB_CONFIG` | e2e's discovery | config file, relative to the project dir |
| `E2E_RB_TARGET` | e2e's rule (the only target) | target name |
| `E2E_RB_HEADED` | `0` | `1` runs the browser headed |
| `E2E_RB_NODE` | `node` | Node executable (`^22.22.3 \|\| >=24.8.0`) |
| `E2E_RB_TIMEOUT_MS` | config's `timeout` | per-test session deadline |
| `E2E_RB_VERBOSE` | `0` | `1` prints every e2e step |

The same settings are on `E2eRb.configure { |c| ... }`.

Fails loudly on: an e2e version outside `E2eRb::E2E_REQUIREMENT` (`~> 0.23.1`), a protocol
mismatch, a missing `node_modules/e2e`, an unknown fixture, a missing model (`MODEL_UNAVAILABLE`).

### RSpec

```ruby
require "e2e_rb/rspec"   # tag groups with type: :e2e
```
Matchers: `be_visible be_hidden be_attached be_enabled be_disabled be_checked be_selected
be_expanded be_focused have_text contain_text have_value have_attribute have_count
have_accessible_name have_screenshot` (all take e2e's options, e.g. `timeout: 500`).

### Minitest

```ruby
require "e2e_rb/minitest"   # subclass E2eRb::Minitest::Test
```
`assert_visible refute_visible assert_text refute_text assert_contains_text assert_value
assert_count assert_checked assert_enabled`, or any matcher via `e2e_expect(loc).to_have_text(...)`.

## Parallelism

e2e allows one hosted session per process, so parallelize with processes (parallel_tests,
`rspec` per shard), not threads. A forked worker starts its own bridge. `parallelize_me!` raises.
Use a port-0 app URL (`http://127.0.0.1:0` + `env: { PORT: '{port}' }`) so each worker's app
gets its own free port.

## Known limit: replay cache

e2e's public host API (`openHost`) does not give hosted sessions a stable test identity or a
verdict, so **`agent.act` calls the model on every run** under e2e_rb (no record/replay yet).
Deterministic steps are unaffected. Fixing it needs an upstream e2e change
(`openSession({ testId, attempt })` + a verdict on close).

## Develop

Everything runs in Docker (Playwright image + Ruby):

```bash
cp .env.example .env
docker compose build
docker compose run --rm test          # unit specs, RSpec example, Minitest example
docker compose run --rm test bundle exec rspec example/spec/agentic_spec.rb   # needs E2E_MODEL + AI_GATEWAY_API_KEY
```

Not yet: `agent.extract` with a schema (Standard Schema has no wire form yet), custom
`test.extend()` fixtures, Rails system-test integration.
