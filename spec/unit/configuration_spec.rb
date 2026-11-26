# frozen_string_literal: true

require "tmpdir"
require_relative "../../lib/e2e_rb"

RSpec.describe E2eRb::Configuration, "reading env" do
  def config(env) = described_class.new(env)

  it "reads every documented setting" do
    c = config("E2E_RB_PROJECT_DIR" => "/p", "E2E_RB_CONFIG" => "e2e.ci.ts", "E2E_RB_TARGET" => "web",
               "E2E_RB_HEADED" => "1", "E2E_RB_NODE" => "/usr/bin/node", "E2E_RB_TIMEOUT_MS" => "30000",
               "E2E_RB_VERBOSE" => "1")
    expect([c.project_dir, c.config, c.target, c.headed, c.node, c.timeout])
      .to eq(["/p", "e2e.ci.ts", "web", true, "/usr/bin/node", 30_000])
    expect(c.on_step).not_to be_nil
  end

  it "uses the documented defaults when a setting is absent" do
    c = config({})
    expect([c.project_dir, c.config, c.target, c.headed, c.node, c.timeout, c.on_step])
      .to eq([Dir.pwd, nil, nil, false, "node", nil, nil])
  end
end

RSpec.describe E2eRb::Configuration, "malformed env" do
  {
    { "E2E_RB_HEADED" => "true" } => /E2E_RB_HEADED must be 0 or 1, got "true"/,
    { "E2E_RB_VERBOSE" => "yes" } => /E2E_RB_VERBOSE must be 0 or 1/,
    { "E2E_RB_TIMEOUT_MS" => "abc" } => /E2E_RB_TIMEOUT_MS must be a positive integer \(ms\), got "abc"/,
    { "E2E_RB_TIMEOUT_MS" => "0" } => /positive integer/,
    { "E2E_RB_TIMEOUT_MS" => "1.5" } => /positive integer/,
    { "E2E_RB_PROJECT_DIR" => "" } => /project_dir must be a non-empty string/,
    { "E2E_RB_HEADLESS" => "1" } => /unknown setting E2E_RB_HEADLESS; e2e_rb reads E2E_RB_PROJECT_DIR/
  }.each do |env, message|
    it "refuses #{env.inspect}" do
      expect { described_class.new(env) }.to raise_error(E2eRb::ConfigurationError, message)
    end
  end
end

RSpec.describe E2eRb::Configuration, "values set in Ruby" do
  def config(env) = described_class.new(env)

  it "validates them too" do
    c = config({})
    expect { c.headed = "1" }.to raise_error(E2eRb::ConfigurationError, /headed must be true or false/)
    expect { c.timeout = -5 }.to raise_error(E2eRb::ConfigurationError, /timeout must be a positive integer/)
    expect { c.node = nil }.to raise_error(E2eRb::ConfigurationError, /node must be a non-empty string/)
    c.timeout = nil
    expect(c.timeout).to be_nil
  end

  it "requires a package.json in the project directory" do
    Dir.mktmpdir do |dir|
      c = config("E2E_RB_PROJECT_DIR" => dir)
      expect { c.project_root }.to raise_error(E2eRb::ConfigurationError, /#{Regexp.escape(dir)} has no package.json/)
      File.write(File.join(dir, "package.json"), "{}")
      expect(c.project_root).to eq(File.expand_path(dir))
    end
  end
end
