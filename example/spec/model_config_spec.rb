# frozen_string_literal: true

require_relative "support/runs"

# example/e2e.config.ts picks the model from E2E_MODEL_* explicitly; every half-set
# combination must stop the run at config load, naming the variable. Each case is its own
# process (the config is read once per host). Needs no model and no network.
RSpec.describe "the example's model settings, half set" do
  {
    { "E2E_MODEL" => "m" } => /E2E_MODEL_PROVIDER is not set/,
    { "E2E_MODEL" => "m", "E2E_MODEL_PROVIDER" => "ollama" } =>
      /E2E_MODEL_PROVIDER must be openai-compatible or gateway, got "ollama"/,
    { "E2E_MODEL" => "m", "E2E_MODEL_PROVIDER" => "openai-compatible" } => /E2E_MODEL_BASE_URL is not set/,
    { "E2E_MODEL" => "a/b", "E2E_MODEL_PROVIDER" => "gateway", "E2E_MODEL_BASE_URL" => "http://x/v1" } =>
      /E2E_MODEL_BASE_URL set, but the gateway provider does not read them/,
    { "E2E_MODEL_PROVIDER" => "openai-compatible", "E2E_MODEL_BASE_URL" => "http://x/v1" } =>
      /E2E_MODEL_PROVIDER, E2E_MODEL_BASE_URL set but E2E_MODEL is not/
  }.each do |env, message|
    it "refuses #{env.map { |name, value| "#{name}=#{value}" }.join(" ")}" do
      expect(ExampleRuns.open_with_model_env(env)).to match(message)
    end
  end
end

RSpec.describe "the example's model settings, complete" do
  it "builds an openai-compatible model without contacting it (opening a session needs no request)" do
    env = { "E2E_MODEL" => "m", "E2E_MODEL_PROVIDER" => "openai-compatible", "E2E_MODEL_BASE_URL" => "http://127.0.0.1:9/v1" }
    expect(ExampleRuns.open_with_model_env(env)).to include("OPENED")
  end

  it "runs with no model at all when every name is unset" do
    expect(ExampleRuns.open_with_model_env({})).to include("OPENED")
  end
end
