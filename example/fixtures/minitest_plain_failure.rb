# frozen_string_literal: true

require_relative "../test/test_helper"

# Run by example/spec/reporting_spec.rb: a failure that is not e2e's own still names the trace.
class PlainFailureTest < BrowserTest
  def test_fails_on_a_plain_assertion = assert_equal(1, 2)
end
