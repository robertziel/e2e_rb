# frozen_string_literal: true

module E2eRb
  VERSION = "0.1.0"
  # Bridge <-> gem wire protocol. Bumped on any incompatible change.
  PROTOCOL_VERSION = 1
  # The e2e npm versions this gem is tested against. The project installs e2e;
  # the bridge refuses to start on any other version.
  E2E_REQUIREMENT = Gem::Requirement.new("~> 0.23.1")
end
