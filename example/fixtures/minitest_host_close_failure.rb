# frozen_string_literal: true

require_relative "../test/test_helper"

# Run by example/spec/reporting_spec.rb: the test passes, then the bridge dies before
# the suite closes the e2e host, so the run must fail with the reason.
class HostCloseFailureTest < BrowserTest
  def test_passes_then_the_bridge_dies
    assert_visible screen.get_by_role("heading", "say hello")
    e2e_close
    pid = E2eRb.runtime.bridge.pid
    Process.kill("KILL", pid)
    sleep 0.05 while E2eRb.runtime.bridge.alive?
  end
end
