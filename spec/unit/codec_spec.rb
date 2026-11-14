# frozen_string_literal: true

require_relative "../../lib/e2e_rb"

RSpec.describe E2eRb::Codec do
  it "maps Ruby names to e2e names" do
    expect(described_class.js_name(:get_by_role)).to eq("getByRole")
    expect(described_class.js_name(:visible?)).to eq("isVisible")
    expect(described_class.js_name(:to_have_text)).to eq("toHaveText")
    expect(described_class.js_name(:click)).to eq("click")
    expect { described_class.js_name(:click!) }.to raise_error(ArgumentError)
  end

  it "camelizes option keys but keeps params names as written" do
    args = described_class.args(["go {first_name}"], { params: { first_name: "Ada" }, max_steps: 3 })
    expect(args).to eq(["go {first_name}", { "params" => { "first_name" => "Ada" }, "maxSteps" => 3 }])
  end

  it "encodes regexps with their flags" do
    expect(described_class.encode(/hello/i)).to eq("$regex" => { "source" => "hello", "flags" => "i" })
    expect { described_class.encode(/a b/x) }.to raise_error(ArgumentError, /extended/)
  end

  it "encodes secret references without values" do
    expect(described_class.encode(E2eRb.secret(:api_token))).to eq("$secret" => "api_token")
    expect(described_class.encode(E2eRb.credential(:admin, :password))).to eq("$credential" => "admin", "field" => "password")
  end

  it "refuses values it cannot send" do
    expect { described_class.encode(Object.new) }.to raise_error(ArgumentError, /cannot send Object/)
  end
end
