# frozen_string_literal: true

require_relative "../../lib/e2e_rb"

RSpec.describe "E2eRb.error_from_wire" do
  def wire(category, code = "X") = { "message" => "boom", "data" => { "category" => category, "e2eCode" => code } }

  it "maps e2e categories to Ruby classes" do
    expect(E2eRb.error_from_wire(wire("test"))).to be_a(E2eRb::Failure)
    expect(E2eRb.error_from_wire(wire("configuration"))).to be_a(E2eRb::ConfigurationError)
    expect(E2eRb.error_from_wire(wire("infrastructure"))).to be_a(E2eRb::InfrastructureError)
    expect(E2eRb.error_from_wire(wire("bridge"))).to be_a(E2eRb::BridgeError)
  end

  it "carries the code and the trace path" do
    error = E2eRb.error_from_wire(wire("test", "TEST_TIMEOUT"), trace_path: "/x/trace.md")
    expect(error.message).to eq("boom [TEST_TIMEOUT]\n  e2e trace: /x/trace.md")
    expect(error.e2e_code).to eq("TEST_TIMEOUT")
  end
end
