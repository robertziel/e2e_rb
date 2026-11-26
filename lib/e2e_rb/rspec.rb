# frozen_string_literal: true

require "rspec/core"
require "rspec/expectations"
require_relative "../e2e_rb"
require_relative "dsl"

module E2eRb
  module RSpec
    # Ruby matcher name -> e2e matcher (from E2eRb::MATCHERS).
    MATCHERS = E2eRb::MATCHERS.to_h { |row| [row[:rspec], row[:e2e]] }.freeze

    # expect(locator).to have_text("x") runs e2e's own auto-waiting matcher in Node.
    class Matcher
      def initialize(ruby_name, e2e_name, positional, options)
        @ruby_name = ruby_name
        @e2e_name = e2e_name
        @positional = positional
        @options = options
      end

      def matches?(actual) = run(actual, negate: false)
      def does_not_match?(actual) = run(actual, negate: true)

      attr_reader :failure_message
      alias failure_message_when_negated failure_message

      def description
        args = @positional.map(&:inspect)
        args << @options.inspect unless @options.empty?
        "#{@ruby_name.to_s.tr("_", " ")}#{" #{args.join(", ")}" unless args.empty?}"
      end

      def supports_block_expectations? = false

      private

      def run(actual, negate:)
        unless actual.respond_to?(:__e2e_subject__)
          raise ArgumentError, "#{@ruby_name} is e2e's matcher and takes a locator or screen, got #{actual.inspect}"
        end

        args = E2eRb::Codec.args(@positional, @options)
        actual.__e2e_session__.run_expectation(actual, @e2e_name, args, negate: negate, soft: false)
        true
      rescue E2eRb::Failure => e
        @failure_message = e.message
        false
      end
    end

    # be_visible, have_text, ...: one RSpec matcher per row of E2eRb::MATCHERS.
    module Matchers
      MATCHERS.each do |ruby_name, e2e_name|
        define_method(ruby_name) { |*positional, **options| Matcher.new(ruby_name, e2e_name, positional, options) }
      end
    end

    module DSL
      include E2eRb::DSL
      include Matchers
    end
  end
end

RSpec.configure do |config|
  config.include E2eRb::RSpec::DSL, type: :e2e

  config.before(:each, type: :e2e) do |example|
    # e2e test failures are RSpec expectation failures, not errors.
    e2e_open(example.metadata[:full_description], failure_class: RSpec::Expectations::ExpectationNotMetError)
  end

  config.after(:each, type: :e2e) do |example|
    message = e2e_close
    raise E2eRb.failure(message, failure_class: RSpec::Expectations::ExpectationNotMetError) if message
  ensure
    e2e_annotate(example.exception) if example.exception
  end

  # The host (app, engine) closes with the suite; a close failure fails the run.
  config.after(:suite) { E2eRb.close! }
end
