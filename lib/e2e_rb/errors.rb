# frozen_string_literal: true

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

  # Failure class used when no adapter is loaded.
  class TestFailure < Error; end

  class << self
    # Set by the adapter to its framework's failure class (the exact class:
    # Minitest counts failures by exact class, not subclasses).
    attr_writer :failure_class

    def failure_class
      @failure_class || TestFailure
    end

    def failure(message, code: nil)
      exception = failure_class.new(message).extend(Failure)
      exception.e2e_code = code
      exception
    end

    # Builds the exception for one error the bridge reported.
    def error_from_wire(error, trace_path: nil)
      data = error["data"] || {}
      message = error["message"].to_s
      message += " [#{data["e2eCode"]}]" if data["e2eCode"]
      message += "\n  e2e trace: #{trace_path}" if trace_path
      case data["category"]
      when "test" then failure(message, code: data["e2eCode"])
      when "configuration" then ConfigurationError.new(message)
      when "bridge" then BridgeError.new(message)
      else InfrastructureError.new(message)
      end
    end
  end
end
