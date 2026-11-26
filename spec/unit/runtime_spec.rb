# frozen_string_literal: true

require_relative "../../lib/e2e_rb"
require_relative "../support/doubles"

# Runtime#close! (the adapters' suite-end hook) against a scripted bridge.
RSpec.describe E2eRb::Runtime, "#close!" do
  def runtime_with(bridge)
    described_class.new(E2eRb::Configuration.new({})).tap do |runtime|
      runtime.instance_variable_set(:@bridge, bridge)
      runtime.instance_variable_set(:@host_open, true)
    end
  end

  def bridge(&) = E2eRbSpec::ScriptedBridge.new(&)

  it "closes the host, then shuts the bridge down" do
    b = bridge { { "failures" => [] } }
    runtime_with(b).close!
    expect(b.calls).to eq(["host/close", :shutdown])
  end

  it "raises the failures e2e reports at host close, after shutting the bridge down" do
    b = bridge { { "failures" => [{ "message" => "app exited 1" }, { "message" => "trace not written" }] } }
    expect { runtime_with(b).close! }
      .to raise_error(E2eRb::InfrastructureError, "e2e host close failed: app exited 1; trace not written")
    expect(b.calls).to eq(["host/close", :shutdown])
  end

  it "is a no-op once closed, and in a process that never opened a host" do
    b = bridge { { "failures" => [] } }
    runtime = runtime_with(b)
    2.times { runtime.close! }
    expect(b.calls).to eq(["host/close", :shutdown])
    expect { described_class.new(E2eRb::Configuration.new({})).close! }.not_to raise_error
  end
end

RSpec.describe E2eRb::Runtime, "#close! when the host cannot close" do
  def runtime_with(bridge)
    described_class.new(E2eRb::Configuration.new({})).tap do |runtime|
      runtime.instance_variable_set(:@bridge, bridge)
      runtime.instance_variable_set(:@host_open, true)
    end
  end

  it "reports a dead bridge as a host-close failure and reaps it" do
    b = E2eRbSpec::ScriptedBridge.new { raise E2eRb::BridgeError, "e2e bridge exited during host/close: signal 9" }
    expect { runtime_with(b).close! }
      .to raise_error(E2eRb::InfrastructureError,
                      %r{the bridge is gone \(e2e bridge exited during host/close: signal 9\)})
    expect(b.calls).to eq(["host/close", :reap])
  end

  it "wraps an error e2e raises from host close and still shuts the bridge down" do
    b = E2eRbSpec::ScriptedBridge.new { raise E2eRb::ConfigurationError, "bad target" }
    expect { runtime_with(b).close! }.to raise_error(E2eRb::InfrastructureError, "e2e host close failed: bad target")
    expect(b.calls).to eq(["host/close", :shutdown])
  end
end
