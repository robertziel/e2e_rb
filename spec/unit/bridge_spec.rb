# frozen_string_literal: true

require "timeout"
require_relative "../../lib/e2e_rb"
require_relative "../support/doubles"

RSpec.describe E2eRb::Bridge, "requests" do
  def bridge(wire, on_notification: ->(*) {})
    described_class.new(node: "node", cwd: "/p", on_notification: on_notification, wire: wire)
  end

  it "skips the reply to a request abandoned by Timeout, then answers the next one" do
    held = nil
    wire = E2eRbSpec::FakeWire.holding_slow { |message| held = message }
    b = bridge(wire)
    expect { Timeout.timeout(0.2) { b.request("slow") } }.to raise_error(Timeout::Error)
    wire.push("id" => held["id"], "result" => { "ok" => "slow" }) # the late reply lands in the pipe
    expect(b.request("fast")).to eq("ok" => "fast")
  end

  it "delivers notifications that arrive before the reply" do
    seen = []
    wire = E2eRbSpec::FakeWire.new do |message|
      next E2eRbSpec::FakeWire.initialize_reply(message) if message["method"] == "initialize"

      [{ "method" => "step", "params" => { "n" => 1 } }, { "id" => message["id"], "result" => {} }]
    end
    bridge(wire, on_notification: ->(m, p) { seen << [m, p] }).request("x")
    expect(seen).to eq([["step", { "n" => 1 }]])
  end
end

RSpec.describe E2eRb::Bridge, "protocol errors" do
  def bridge(wire) = described_class.new(node: "node", cwd: "/p", on_notification: ->(*) {}, wire: wire)

  def answering(&reply)
    E2eRbSpec::FakeWire.new do |message|
      message["method"] == "initialize" ? E2eRbSpec::FakeWire.initialize_reply(message) : reply.call(message)
    end
  end

  it "fails on a reply from the future (a broken protocol, not a late reply)" do
    wire = answering { |message| { "id" => message["id"] + 5, "result" => {} } }
    expect { bridge(wire).request("x") }.to raise_error(E2eRb::BridgeError, /answered request 7, expected 2/)
  end

  it "refuses an e2e version outside E2E_REQUIREMENT" do
    wire = E2eRbSpec::FakeWire.new { |message| { "id" => message["id"], "result" => { "e2eVersion" => "0.24.0" } } }
    expect { bridge(wire) }
      .to raise_error(E2eRb::BridgeError, %r{e2e 0.24.0 is installed in /p; e2e_rb .* needs e2e ~> 0.23.1})
  end

  it "maps a missing member to NoMethodError" do
    error = { "message" => "screen has no member \"hash\"",
              "data" => { "category" => "no_member", "member" => "hash" } }
    wire = answering { |message| { "id" => message["id"], "error" => error } }
    expect { bridge(wire).request("invoke") }.to raise_error(NoMethodError) { |e| expect(e.name).to eq(:hash) }
  end
end
