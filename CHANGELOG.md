# Changelog

All notable changes to e2e_rb. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - unreleased

First release. Works with e2e `~> 0.23.1` (npm), Ruby >= 3.2, RSpec 3.13, Minitest 5 and 6.

### Added
- RSpec adapter (`require "e2e_rb/rspec"`, `type: :e2e`) with e2e's 16 locator/screen matchers.
- Minitest adapter (`require "e2e_rb/minitest"`): `include E2eRb::Minitest` into any `Minitest::Test`
  subclass, or subclass `E2eRb::Minitest::Test`; `assert_*` / `refute_*` for all 16 matchers.
- One e2e session per test through a Node bridge (`bridge/server.mjs`, JSON-RPC 2.0 on fd 3).
- The e2e host closes at the end of the suite; a close failure fails the run.
- Strict settings (`E2E_RB_*` / `E2eRb.configure`): malformed values and unknown `E2E_RB_*` names raise.
- Ruby regexps are translated to JavaScript (`\A`, `\z`, `\Z`, `\h`, line anchors); syntax JavaScript
  lacks raises `ArgumentError`.
- The bridge refuses a Node outside e2e's `engines.node` and results that have no JSON form.
- The gem passes RubyGems' strict validation (`gem build --strict`: no warnings); `rake` runs the unit
  specs and RuboCop, `rake build` packages the gem (strict); there is no `rake release`.
