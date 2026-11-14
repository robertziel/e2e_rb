# frozen_string_literal: true

require "rspec/core"
require "rspec/expectations"
require_relative "../e2e_rb"
require_relative "dsl"

module E2eRb
  module RSpec
    # Ruby matcher name -> e2e matcher.
    MATCHERS = {
      be_visible: "toBeVisible",
      be_hidden: "toBeHidden",
      be_attached: "toBeAttached",
      be_enabled: "toBeEnabled",
      be_disabled: "toBeDisabled",
      be_checked: "toBeChecked",
      be_selected: "toBeSelected",
      be_expanded: "toBeExpanded",
      be_focused: "toBeFocused",
      have_text: "toHaveText",
      contain_text: "toContainText",
      have_value: "toHaveValue",
      have_attribute: "toHaveAttribute",
      have_count: "toHaveCount",
      have_accessible_name: "toHaveAccessibleName",
      have_screenshot: "toHaveScreenshot"
    }.freeze

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

        actual.__e2e_session__.run_expectation(actual, @e2e_name, @positional, @options, negate: negate, soft: false)
        true
      rescue E2eRb::Failure => e
        @failure_message = e.message
        false
      end
    end

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

# e2e test failures are RSpec expectation failures, not errors.
E2eRb.failure_class = RSpec::Expectations::ExpectationNotMetError

RSpec.configure do |config|
  config.include E2eRb::RSpec::DSL, type: :e2e

  config.before(:each, type: :e2e) do |example|
    e2e_open(example.metadata[:full_description])
  end

  config.after(:each, type: :e2e) do
    message = e2e_close
    raise E2eRb.failure(message) if message
  end
end
