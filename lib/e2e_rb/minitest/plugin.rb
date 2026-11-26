# frozen_string_literal: true

# Minitest's plugin hook: Minitest calls plugin_<name>_init for every name in
# Minitest.extensions. e2e_rb's adds the reporter that closes the e2e host at the end
# of the run. Registered when the adapter is required, never by auto-discovery, so a
# suite that does not use e2e_rb is untouched.
module Minitest
  def self.plugin_e2e_rb_init(options)
    reporter << E2eRb::Minitest::HostReporter.new(options.fetch(:io, $stdout))
  end
end
Minitest.extensions << "e2e_rb" unless Minitest.extensions.include?("e2e_rb")
