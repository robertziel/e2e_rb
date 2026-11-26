# frozen_string_literal: true

require "open3"
require "rbconfig"

# Runs Ruby as its own process from the repo root, the way a CI job runs a suite,
# with this checkout's lib on the load path.
module ExampleRuns
  ROOT = File.expand_path("../../..", __dir__)
  MODEL_ENV = %w[E2E_MODEL E2E_MODEL_PROVIDER E2E_MODEL_BASE_URL E2E_MODEL_API_KEY].freeze
  # Opens one session and prints OPENED, or the e2e_rb error that stopped it.
  OPEN_ONE_SESSION = <<~RUBY
    require "e2e_rb"
    begin
      E2eRb.open_session(name: "model config").close
      puts "OPENED"
    rescue E2eRb::Error => e
      puts "\#{e.class}: \#{e.message}"
    end
  RUBY

  # [output, exit code]
  def self.ruby(*, env: {})
    out, status = Open3.capture2e(env, RbConfig.ruby, "-I#{ROOT}/lib", *, chdir: ROOT)
    [out, status.exitstatus]
  end

  def self.fixture(name) = "#{ROOT}/example/fixtures/#{name}"

  # The output of opening one session with exactly these E2E_MODEL_* values set. The script
  # rescues e2e_rb's errors and prints them, so any other exit (a crash) raises here.
  def self.open_with_model_env(env)
    out, code = ruby("-e", OPEN_ONE_SESSION, env: MODEL_ENV.to_h { |name| [name, nil] }.merge(env))
    raise "opening a session exited #{code}:\n#{out}" unless code.zero?

    out
  end
end
