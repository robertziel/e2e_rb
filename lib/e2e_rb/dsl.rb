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

    def e2e_open(name)
      @e2e_session = E2eRb.open_session(name: name)
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
  end
end
