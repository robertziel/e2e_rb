# frozen_string_literal: true

# Run by example/spec/reporting_spec.rb: a failure that is not e2e's own still names the trace.
require "e2e_rb/rspec"

RSpec.describe "plain failure", type: :e2e do
  it "fails on a plain expectation" do
    app.open("/")
    expect(1).to eq(2)
  end
end
