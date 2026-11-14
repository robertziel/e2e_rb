# frozen_string_literal: true

require "minitest"
require_relative "../e2e_rb"
require_relative "dsl"

module E2eRb
  module Minitest
    # class CheckoutTest < E2eRb::Minitest::Test
    #   def test_upgrade = (app.open("/"); agent.act("..."); assert_text(screen.get_by_role("status"), "Pro"))
    # end
    class Test < ::Minitest::Test
      include E2eRb::DSL

      # e2e allows one session per process: never run these tests in threads.
      def self.parallelize_me!
        raise E2eRb::Error, "e2e allows one session per process; parallelize with processes (e.g. parallel_tests), not parallelize_me!"
      end

      def before_setup
        super
        e2e_open("#{self.class.name}##{name}")
      end

      def after_teardown
        message = e2e_close
        raise E2eRb.failure(message) if message
      ensure
        super
      end

      # e2e_expect(...) counted as one Minitest assertion.
      def e2e_expect(subject, soft: false)
        self.assertions += 1
        super
      end

      def assert_visible(locator, **options) = e2e_expect(locator).to_be_visible(**options)
      def refute_visible(locator, **options) = e2e_expect(locator).not.to_be_visible(**options)
      def assert_text(locator, expected, **options) = e2e_expect(locator).to_have_text(expected, **options)
      def refute_text(locator, expected, **options) = e2e_expect(locator).not.to_have_text(expected, **options)
      def assert_contains_text(locator, expected, **options) = e2e_expect(locator).to_contain_text(expected, **options)
      def assert_value(locator, expected, **options) = e2e_expect(locator).to_have_value(expected, **options)
      def assert_count(locator, expected, **options) = e2e_expect(locator).to_have_count(expected, **options)
      def assert_checked(locator, **options) = e2e_expect(locator).to_be_checked(**options)
      def assert_enabled(locator, **options) = e2e_expect(locator).to_be_enabled(**options)
    end
  end
end

# e2e test failures are Minitest failures, not errors.
E2eRb.failure_class = Minitest::Assertion
