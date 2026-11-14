# frozen_string_literal: true

require_relative "../../lib/e2e_rb"

RSpec.describe E2eRb::Proxy do
  let(:calls) { [] }
  let(:session) do
    calls = self.calls
    Class.new do
      define_method(:invoke) do |root, chain|
        calls << [root, chain]
        case chain.last["m"]
        when "getByRole", "first" then { "kind" => "locator" }
        when "all" then { "kind" => "locators", "count" => 2 }
        when "count" then { "kind" => "value", "value" => 3 }
        else { "kind" => "value", "value" => nil }
        end
      end
    end.new
  end
  let(:screen) { described_class.new(session, "screen") }

  it "builds locator chains and sends actions with the whole chain" do
    screen.get_by_role("button", name: "greet").first.click
    expect(calls.last).to eq(["screen", [
      { "m" => "getByRole", "a" => ["button", { "name" => "greet" }] },
      { "m" => "first", "a" => [] },
      { "m" => "click", "a" => [] }
    ]])
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

  it "routes tap to e2e, not Object#tap" do
    screen.get_by_role("button").tap
    expect(calls.last[1].last).to eq("m" => "tap", "a" => [])
  end

  it "passes locators as arguments" do
    target = screen.get_by_role("button")
    screen.get_by_role("button").first.drag_to(target)
    expect(calls.last[1].last["a"]).to eq([{ "$locator" => { "root" => "screen", "chain" => [{ "m" => "getByRole", "a" => ["button"] }] } }])
  end

  it "keeps Ruby's implicit conversions away from e2e" do
    expect { [screen].flatten }.not_to(change { calls.size })
    expect { screen.to_str }.to raise_error(NoMethodError)
  end
end
