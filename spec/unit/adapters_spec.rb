# frozen_string_literal: true

require_relative "../../lib/e2e_rb"
require_relative "../../lib/e2e_rb/minitest"

RSpec.describe E2eRb::Minitest, "threads" do
  it "refuses Minitest's threads on a class that includes E2eRb::Minitest, and on E2eRb::Minitest::Test" do
    base = Class.new(Minitest::Test)
    including = Class.new(base) { include E2eRb::Minitest }
    expect { including.parallelize_me! }.to raise_error(E2eRb::Error, /one session per process/)
    expect { Class.new(including).parallelize_me! }.to raise_error(E2eRb::Error, /one session per process/)
    expect { Class.new(E2eRb::Minitest::Test).parallelize_me! }.to raise_error(E2eRb::Error, /one session per process/)
  end

  it "refuses a class made parallel another way before any session opens" do
    parallel = Class.new(Minitest::Test) do
      include E2eRb::Minitest

      # Minitest 6 names it run_order, Minitest 5 test_order.
      define_singleton_method(Minitest::Test.respond_to?(:run_order) ? :run_order : :test_order) { :parallel }
      def test_x; end
    end
    expect(E2eRb).not_to receive(:open_session)
    expect { parallel.new("test_x").before_setup }.to raise_error(E2eRb::Error, /one session per process/)
  end
end

RSpec.describe E2eRb::Minitest, "assertions and the host reporter" do
  it "generates assert_ and refute_ for every matcher in E2eRb::MATCHERS" do
    names = E2eRb::MATCHERS.flat_map { |row| [:"assert_#{row[:minitest]}", :"refute_#{row[:minitest]}"] }
    expect(E2eRb::Minitest.instance_methods).to include(*names)
    expect(names.size).to eq(32)
  end

  it "registers the reporter that closes the e2e host" do
    expect(Minitest.extensions).to include("e2e_rb")
    expect(Minitest).to respond_to(:plugin_e2e_rb_init)
  end

  it "fails the Minitest run when the host close fails" do
    reporter = E2eRb::Minitest::HostReporter.new(StringIO.new)
    allow(E2eRb).to receive(:close!).and_raise(E2eRb::InfrastructureError, "e2e host close failed: app exited 1")
    reporter.report
    expect(reporter.passed?).to be(false)
  end
end
