# frozen_string_literal: true

require_relative "../../lib/e2e_rb"
require_relative "../support/doubles"

RSpec.describe E2eRb::Proxy, "call chains" do
  let(:calls) { [] }
  let(:screen) { described_class.new(E2eRbSpec::RecordingSession.new(calls), "screen") }

  it "builds locator chains and sends actions with the whole chain" do
    screen.get_by_role("button", name: "greet").first.click
    expect(calls.last).to eq(["screen", [{ "m" => "getByRole", "a" => ["button", { "name" => "greet" }] },
                                         { "m" => "first", "a" => [] }, { "m" => "click", "a" => [] }]])
  end

  it "returns plain values" do
    expect(screen.get_by_role("listitem").count).to eq(3)
  end

  it "expands all() into nth() locators" do
    items = screen.get_by_role("listitem").all
    expect(items.size).to eq(2)
    items[1].click
    expect(calls.last[1].last(2)).to eq([{ "m" => "nth", "a" => [1] }, { "m" => "click", "a" => [] }])
  end
end

RSpec.describe E2eRb::Proxy, "Ruby's own methods" do
  let(:calls) { [] }
  let(:screen) { described_class.new(E2eRbSpec::RecordingSession.new(calls), "screen") }

  it "routes tap to e2e, not Object#tap" do
    screen.get_by_role("button").tap
    expect(calls.last[1].last).to eq("m" => "tap", "a" => [])
  end

  it "passes locators as arguments" do
    target = screen.get_by_role("button")
    screen.get_by_role("button").first.drag_to(target)
    locator = { "root" => "screen", "chain" => [{ "m" => "getByRole", "a" => ["button"] }] }
    expect(calls.last[1].last["a"]).to eq([{ "$locator" => locator }])
  end

  it "keeps Ruby's implicit conversions away from e2e" do
    expect { [screen].flatten }.not_to(change { calls.size })
    expect { screen.to_str }.to raise_error(NoMethodError)
  end
end

RSpec.describe E2eRb::Proxy, "as a value" do
  let(:session) { Object.new }

  it "is equal to a proxy of the same expression in the same session, and hashes alike" do
    a = described_class.new(session, "screen", [{ "m" => "getByRole", "a" => ["button"] }])
    b = described_class.new(session, "screen", [{ "m" => "getByRole", "a" => ["button"] }])
    c = described_class.new(session, "screen", [{ "m" => "getByRole", "a" => ["link"] }])
    expect(a == b).to be(true)
    expect(a.eql?(b)).to be(true)
    expect(a == c).to be(false)
    expect({ a => 1 }[b]).to eq(1)
    expect([a].include?(b)).to be(true)
    expect(a == described_class.new(Object.new, "screen", [{ "m" => "getByRole", "a" => ["button"] }])).to be(false)
    expect(a == "screen").to be(false)
  end
end
