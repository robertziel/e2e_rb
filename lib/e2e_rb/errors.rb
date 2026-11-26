# frozen_string_literal: true

# The exceptions e2e_rb raises, and how an error the bridge reports becomes one.
module E2eRb
  # Anything e2e_rb raises.
  class Error < StandardError; end

  # The bridge process could not start, died, or broke the protocol.
  class BridgeError < Error; end

  # e2e refused the config, the target, a secret, etc. (category: configuration).
  class ConfigurationError < Error; end

  # e2e failed to drive the app (category: infrastructure / internal).
  class InfrastructureError < Error; end

  # Marks a test failure: a failed expect, a failed agent.assert, a timeout.
  # The exception itself is the framework's own failure class (Minitest::Assertion,
  # RSpec::Expectations::ExpectationNotMetError), extended with this module, so the
  # framework counts it as a failure and `rescue E2eRb::Failure` still matches.
  module Failure
    attr_accessor :e2e_code
  end

  # Failure class used when no adapter opened the session (plain E2eRb.open_session).
  class TestFailure < Error; end

  # A member the e2e object does not have (`screen.no_such_thing`): a NoMethodError,
  # as for any Ruby object, not a bridge error.
  class NoMemberError < ::NoMethodError; end

  # The bridge's error categories other than test failures; any other is infrastructure.
  WIRE_CATEGORIES = { "configuration" => ConfigurationError, "bridge" => BridgeError }.freeze

  class << self
    # failure_class: the framework's own failure class (the exact class: Minitest
    # counts failures by exact class, not subclasses), given per session by the adapter.
    def failure(message, code: nil, failure_class: TestFailure)
      exception = failure_class.new(message).extend(Failure)
      exception.e2e_code = code
      exception
    end

    # Builds the exception for one error the bridge reported.
    def error_from_wire(error, trace_path: nil, failure_class: TestFailure)
      data = error["data"] || {}
      category = data["category"]
      return NoMemberError.new(error["message"].to_s, data["member"]&.to_sym) if category == "no_member"

      message = wire_message(error["message"], data["e2eCode"], trace_path)
      return failure(message, code: data["e2eCode"], failure_class: failure_class) if category == "test"

      WIRE_CATEGORIES.fetch(category, InfrastructureError).new(message)
    end

    private

    def wire_message(message, code, trace_path)
      text = message.to_s
      text += " [#{code}]" if code
      text += "\n  e2e trace: #{trace_path}" if trace_path
      text
    end
  end
end
