# frozen_string_literal: true

module E2eRb
  # One e2e test attempt. Hands out the fixtures and runs expectations.
  class Session
    attr_reader :name, :attempt_id, :artifacts_dir, :trace_path, :fixture_names

    def initialize(runtime, name:, info:)
      @runtime = runtime
      @name = name
      @attempt_id = info.fetch("attemptId")
      @artifacts_dir = info.fetch("artifactsDir")
      @trace_path = info.fetch("tracePath")
      @fixture_names = info.fetch("fixtures")
      @closed = false
    end

    def app = fixture("app")
    def screen = fixture("screen")
    def agent = fixture("agent")
    def platform = fixture("platform")

    # Any fixture the target's engine contributes.
    def fixture(name)
      name = name.to_s
      raise ConfigurationError, "this target has no fixture #{name.inspect} (has: #{@fixture_names.join(", ")})" unless @fixture_names.include?(name)

      Proxy.new(self, name)
    end

    def expect(subject, soft: false) = Expectation.new(self, subject, soft: soft)

    def invoke(root, chain)
      call("invoke", "root" => root, "chain" => chain)
    end

    def run_expectation(subject, matcher, positional, options, negate:, soft:)
      call("expect",
           "subject" => subject.__e2e_subject__,
           "matcher" => matcher,
           "args" => Codec.args(positional, options),
           "negate" => negate,
           "soft" => soft)
      nil
    end

    # Ends the attempt and writes trace.md. Returns e2e's soft/cleanup failures.
    def close
      return @failures if @closed

      @closed = true
      result = @runtime.close_session(self)
      @failures = result.fetch("failures")
    end

    def closed? = @closed

    private

    def call(method, params)
      raise Error, "session #{@name.inspect} is closed" if @closed

      @runtime.bridge.request(method, params) { |error| E2eRb.error_from_wire(error, trace_path: @trace_path) }
    end
  end

  # session.expect(locator).to_have_text("x") / .not.to_be_visible
  class Expectation
    def initialize(session, subject, soft:, negate: false)
      unless subject.respond_to?(:__e2e_subject__)
        raise ArgumentError, "e2e expectations take a locator or screen, got #{subject.inspect}; use your framework's own assertions for plain values"
      end

      @session = session
      @subject = subject
      @soft = soft
      @negate = negate
    end

    def not = Expectation.new(@session, @subject, soft: @soft, negate: !@negate)

    def method_missing(name, *positional, **options)
      return super unless name.start_with?("to_")

      @session.run_expectation(@subject, Codec.js_name(name), positional, options, negate: @negate, soft: @soft)
    end

    def respond_to_missing?(name, include_private = false) = name.start_with?("to_") || super
  end
end
