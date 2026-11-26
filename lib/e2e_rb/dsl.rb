# frozen_string_literal: true

module E2eRb
  # Methods both adapters mix into a test: app, screen, agent, e2e_expect, ...
  module DSL
    def e2e_session
      @e2e_session || raise(Error, "no e2e session is open for this test")
    end

    def app = e2e_session.app
    def screen = e2e_session.screen
    def agent = e2e_session.agent
    def platform = e2e_session.platform
    def e2e_fixture(name) = e2e_session.fixture(name)

    # e2e_expect(screen.get_by_role("status")).to_have_text("hello")
    def e2e_expect(subject, soft: false) = e2e_session.expect(subject, soft: soft)

    def secret(name) = E2eRb.secret(name)
    def credential(name, field) = E2eRb.credential(name, field)

    private

    def e2e_open(name, failure_class:)
      @e2e_trace_path = nil
      @e2e_session = E2eRb.open_session(name: name, failure_class: failure_class)
      @e2e_trace_path = @e2e_session.trace_path
    end

    # Closes the attempt; returns the failure message e2e reported, or nil.
    def e2e_close
      session = @e2e_session
      return nil unless session

      @e2e_session = nil
      failures = session.close
      return nil if failures.empty?

      "e2e reported #{failures.size} failure(s) at close:\n" +
        failures.map { |f| "  - #{f["message"]}#{" [#{f["code"]}]" if f["code"]}" }.join("\n") +
        "\n  e2e trace: #{session.trace_path}"
    end

    # Adds the test's trace.md path to a failure that does not name it yet (a plain
    # assert_equal, an exception from the test's own code), so every failed e2e test
    # points at its trace.
    def e2e_annotate(exception)
      trace = @e2e_trace_path
      return exception if trace.nil? || exception.message.include?(trace)

      line = "\n  e2e trace: #{trace}"
      exception.singleton_class.define_method(:message) { "#{super()}#{line}" }
      exception
    end
  end
end
