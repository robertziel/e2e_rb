# frozen_string_literal: true

require "minitest/autorun"
require "e2e_rb/minitest"

class GreetingTest < E2eRb::Minitest::Test
  def setup = app.open("/")

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
end
