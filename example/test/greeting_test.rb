# frozen_string_literal: true

require_relative "test_helper"

# The example app's greeting, through a suite's own base class + include E2eRb::Minitest.
class GreetingTest < BrowserTest
  def test_asks_for_a_name
    screen.get_by_role("button", "greet").click
    assert_text screen.get_by_role("alert"), "enter a name first."
  end

  def test_greets_the_name_you_type
    screen.get_by_label("name").fill("Ada")
    screen.get_by_role("button", "greet").click
    assert_text screen.get_by_role("status"), "hello, Ada!"
    assert_equal 1, screen.get_by_role("status").count
  end

  def test_keeps_the_suites_own_base_class
    assert_equal :from_the_suite, app_helper
  end

  # The base-class form still works.
  class SubclassFormTest < E2eRb::Minitest::Test
    def test_opens_a_session
      app.open("/")
      assert_visible screen.get_by_role("heading", "say hello")
    end
  end
end
