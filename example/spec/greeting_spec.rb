# frozen_string_literal: true

require "e2e_rb/rspec"

RSpec.describe "greeting page", type: :e2e do
  before { app.open("/") }

  it "shows the form" do
    expect(screen.get_by_role("heading", "say hello")).to be_visible
    expect(screen.get_by_label("name")).to be_visible
  end

  it "asks for a name when the field is empty" do
    screen.get_by_role("button", "greet").click
    expect(screen.get_by_role("alert")).to have_text("enter a name first.")
  end

  it "greets the name you type" do
    screen.get_by_label("name").fill("Ada")
    screen.get_by_role("button", "greet").click
    expect(screen.get_by_role("status")).to have_text(/hello, ada/i)
    expect(screen.get_by_role("status")).not_to have_text("hello, Grace!")
    expect(screen.get_by_label("name").input_value).to eq("Ada")
  end
end

RSpec.describe "failure reporting", type: :e2e do
  before { app.open("/") }

  it "turns a failed e2e expectation into an RSpec failure with the trace path" do
    expect {
      expect(screen.get_by_role("heading")).to have_text("wrong heading", timeout: 500)
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /e2e trace: .*trace\.md/)
  end

  it "raises a configuration error for an unknown fixture" do
    expect { e2e_fixture("nope") }.to raise_error(E2eRb::ConfigurationError, /no fixture "nope"/)
  end
end
