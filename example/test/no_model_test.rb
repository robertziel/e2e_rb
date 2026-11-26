# frozen_string_literal: true

require_relative "test_helper"

# The deterministic gate's contract: with no model configured, an agent step fails at
# once with e2e's MODEL_UNAVAILABLE (CI runs this with no network at all), and
# everything deterministic keeps working. Uses its own session (not the adapter's),
# because e2e also reports the failed agent step when the session closes.
class NoModelTest < Minitest::Test
  def setup
    @session = E2eRb.open_session(name: "no model contract", failure_class: Minitest::Assertion)
    @session.app.open("/")
  end

  def teardown
    return unless @session # setup failed before a session opened

    assert_equal ["MODEL_UNAVAILABLE"], @session.close.map { |f| f["code"] }.uniq
  end

  def test_agent_steps_fail_fast_without_a_model
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = assert_raises(E2eRb::ConfigurationError) { @session.agent.act("press greet") }

    assert_match(/\[MODEL_UNAVAILABLE\]/, error.message)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2,
                    "an agent step without a model must fail at once, not wait on a network"
    @session.screen.get_by_role("button", "greet").click
    @session.expect(@session.screen.get_by_role("alert")).to_have_text("enter a name first.")
  end
end
