# frozen_string_literal: true

require "minitest"
require_relative "../e2e_rb"
require_relative "dsl"

module E2eRb
  # Include into any Minitest::Test subclass, e.g. a suite's existing base class:
  #
  #   class BrowserTest < MyApp::Test
  #     include E2eRb::Minitest
  #     def test_upgrade = (app.open("/"); assert_text(screen.get_by_role("status"), "Pro"))
  #   end
  #
  # Every test opens one e2e session before setup and closes it after teardown.
  # e2e allows one session per process: parallelize with processes, never threads.
  module Minitest
    include E2eRb::DSL

    THREADS_REFUSED = "e2e allows one session per process; parallelize with processes (one Ruby process per " \
                      "test file, parallel_tests, ...), not Minitest's threads (parallelize_me!)"

    # Refuses parallelize_me! on the including class and its subclasses.
    module ClassMethods
      def parallelize_me!
        raise E2eRb::Error, THREADS_REFUSED
      end
    end

    # The class runs its tests in Minitest's threads (Minitest 6: run_order, Minitest 5: test_order).
    def self.parallel?(klass)
      %i[run_order test_order].any? { |order| klass.respond_to?(order) && klass.public_send(order) == :parallel }
    end

    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    # Closes the e2e host when the run ends; a close failure fails the run
    # (Minitest's exit status follows the reporters' passed?).
    class HostReporter < ::Minitest::AbstractReporter
      def initialize(io)
        super()
        @io = io
        @error = nil
      end

      def report
        E2eRb.close!
      rescue E2eRb::Error => e
        @error = e
        @io.puts("\n#{e.class}: #{e.message}")
      end

      def passed? = @error.nil?
    end

    def before_setup
      # A class made parallel some other way still runs in threads.
      raise E2eRb::Error, THREADS_REFUSED if E2eRb::Minitest.parallel?(self.class)

      super
      e2e_open("#{self.class.name}##{name}", failure_class: ::Minitest::Assertion)
    end

    def after_teardown
      message = e2e_close
      raise E2eRb.failure(message, failure_class: ::Minitest::Assertion) if message
    ensure
      super
      failures.each { |failure| e2e_annotate(failure.respond_to?(:error) ? failure.error : failure) }
    end

    # e2e_expect(...) counted as one Minitest assertion.
    def e2e_expect(subject, soft: false)
      self.assertions += 1
      super
    end

    E2eRb::MATCHERS.each do |row|
      e2e = row[:e2e]
      define_method(:"assert_#{row[:minitest]}") do |subject, *args, **options|
        e2e_expect(subject).matcher(e2e, *args, **options)
      end
      define_method(:"refute_#{row[:minitest]}") do |subject, *args, **options|
        e2e_expect(subject).not.matcher(e2e, *args, **options)
      end
    end

    # `class FooTest < E2eRb::Minitest::Test`: the same, as a base class.
    class Test < ::Minitest::Test
      include E2eRb::Minitest
    end
  end
end

require_relative "minitest/plugin"
