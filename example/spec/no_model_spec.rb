# frozen_string_literal: true

require "e2e_rb/rspec"

# The deterministic gate's contract, RSpec side (example/test/no_model_test.rb is the
# Minitest side): no model configured → an agent step fails at once with
# MODEL_UNAVAILABLE; deterministic steps keep working.
RSpec.describe "running without a model" do
  it "fails an agent step at once with MODEL_UNAVAILABLE and keeps deterministic steps working" do
    session = E2eRb.open_session(name: "no model contract (rspec)", failure_class: RSpec::Expectations::ExpectationNotMetError)
    session.app.open("/")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect { session.agent.act("press greet") }.to raise_error(E2eRb::ConfigurationError, /\[MODEL_UNAVAILABLE\]/)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    session.screen.get_by_role("button", "greet").click
    session.expect(session.screen.get_by_role("alert")).to_have_text("enter a name first.")
    expect(session.close.map { |f| f["code"] }.uniq).to eq(["MODEL_UNAVAILABLE"])
  end
end
