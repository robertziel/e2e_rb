# frozen_string_literal: true

require "stringio"
require_relative "../../lib/e2e_rb"

RSpec.describe E2eRb::Wire do
  it "round-trips a framed message, multibyte included" do
    io = StringIO.new
    described_class.new(nil, io).write("id" => 1, "method" => "x", "params" => { "s" => "zażółć" })
    io.rewind
    expect(described_class.new(io, nil).read).to eq("jsonrpc" => "2.0", "id" => 1, "method" => "x", "params" => { "s" => "zażółć" })
  end

  it "returns nil at end of stream" do
    expect(described_class.new(StringIO.new, nil).read).to be_nil
  end

  it "fails on a frame without Content-Length" do
    expect { described_class.new(StringIO.new("X: 1\r\n\r\n{}"), nil).read }.to raise_error(E2eRb::BridgeError, /Content-Length/)
  end
end
