# Contributing to e2e_rb

Bug reports, fixes and features are welcome. For a larger change, open an issue first so the design can be agreed
before the code.

## Setup

Everything runs in Docker; the host needs only Docker with Compose.

```bash
cp .env.example .env
docker compose build
docker compose run --rm test       # RuboCop, bridge tests, unit specs, RSpec + Minitest examples, parallel workers, gem install
```

| command | what it runs | needs |
| --- | --- | --- |
| `docker compose run --rm test` | the deterministic suite (`scripts/ci/suite.sh`: RuboCop, bridge tests, specs, examples), no network | Docker |
| `docker compose run --rm agentic` | agent steps against a real model | `E2E_MODEL_*` in `.env` ([`.env.example`](.env.example)) |
| `scripts/ci/test.sh matrix` | the suite on Ruby 3.2 / 3.3 / 3.4 / 4.0 with Minitest 6, and Ruby 3.2 with Minitest 5 | Docker |

## A pull request

- One change per PR, with tests that fail without it.
- `docker compose run --rm test` green (it includes RuboCop). A failing check is fixed in the code: no `skip`, no
  `rubocop:disable`, no loosened limit.
- No silent fallbacks: when something the code needs is missing (a model, a Node version, an e2e version), it
  fails with an error that names what is missing.
- No hard-coded hosts, ports or models: configuration comes from `e2e.config.ts`, `E2E_RB_*` env or
  `E2eRb.configure`.
- A user-visible change adds a line under the unreleased version in [CHANGELOG.md](CHANGELOG.md), and updates
  the README when it changes how the gem is used.
- Fill in the PR template: what changed, why, how it was verified.

## Reporting a bug

Open an issue with the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md). Security issues go through
[SECURITY.md](SECURITY.md), not an issue.

## License

By contributing you agree that your contribution is licensed under the [Apache-2.0 license](LICENSE).
