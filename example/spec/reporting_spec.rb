# frozen_string_literal: true

require_relative "support/runs"

# Runs the failing fixtures in example/fixtures/ as their own processes, as a CI job
# would, and checks what the run reports and how it exits.
RSpec.describe "failure reporting across a Minitest run" do
  it "names the trace for a plain Minitest failure inside an e2e test" do
    out, code = ExampleRuns.ruby(ExampleRuns.fixture("minitest_plain_failure.rb"))
    expect(code).to eq(1)
    expect(out).to match(/Expected: 1\n\s+Actual: 2\n\s+e2e trace: \S+trace\.md/)
  end

  it "fails a run whose e2e host cannot close, with a one-line reason" do
    out, code = ExampleRuns.ruby(ExampleRuns.fixture("minitest_host_close_failure.rb"))
    expect(out).to include("1 runs, 1 assertions, 0 failures, 0 errors")
    expect(out).to match(/^E2eRb::InfrastructureError: e2e host close failed: the bridge is gone/)
    expect(code).to eq(1)
  end
end

RSpec.describe "failure reporting across an RSpec run" do
  it "names the trace for a plain RSpec failure inside an e2e example" do
    out, code = ExampleRuns.ruby("-S", "rspec", ExampleRuns.fixture("rspec_plain_failure_spec.rb"))
    expect(code).to eq(1)
    expect(out).to match(/expected: 2\n\s+got: 1.*e2e trace: \S+trace\.md/m)
  end

  it "fails a run whose e2e host cannot close, with the reason" do
    out, code = ExampleRuns.ruby("-S", "rspec", ExampleRuns.fixture("rspec_host_close_failure_spec.rb"))
    expect(out).to include("1 example, 0 failures")
    expect(out).to match(/E2eRb::InfrastructureError:\s+e2e host close failed: the bridge is gone/)
    expect(code).not_to eq(0)
  end
end
