# frozen_string_literal: true

# Run by example/spec/reporting_spec.rb: the example passes, then the bridge dies before
# the suite closes the e2e host, so the run must fail with the reason.
require "e2e_rb/rspec"

RSpec.describe "host close failure", type: :e2e do
  it "passes, then the bridge dies" do
    app.open("/")
    expect(screen.get_by_role("heading", "say hello")).to be_visible
    e2e_close
    Process.kill("KILL", E2eRb.runtime.bridge.pid)
    sleep 0.05 while E2eRb.runtime.bridge.alive?
  end
end
