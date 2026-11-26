# frozen_string_literal: true

require_relative "test_helper"

# Every generated assert_/refute_ pair against the example page.
class MatchersTest < BrowserTest
  def heading = screen.get_by_role("heading", "say hello")
  def details = screen.get_by_text("details")
  def news = screen.get_by_label("newsletter")
  def more = screen.get_by_role("button", "more")
  def archive = screen.get_by_role("button", "archive")
  def greet = screen.get_by_role("button", "greet")
  def name_field = screen.get_by_label("name")
  def tab(name) = screen.get_by_role("tab", name)
  def items = screen.get_by_role("listitem")

  def test_visibility_and_presence
    assert_visible heading
    refute_visible details
    assert_hidden details
    refute_hidden heading
    assert_attached heading
    refute_attached screen.get_by_role("dialog")
  end

  def test_enabled_and_checked
    assert_enabled more
    refute_enabled archive
    assert_disabled archive
    refute_disabled more
    refute_checked news
    news.check
    assert_checked news
  end

  def test_selected_expanded_focused
    assert_selected tab("one")
    refute_selected tab("two")
    refute_expanded more
    more.click
    assert_expanded more
    name_field.click
    assert_focused name_field
    refute_focused more
  end

  def test_text
    assert_text heading, "say hello"
    refute_text heading, "say goodbye"
    assert_contains_text heading, "hello"
    refute_contains_text heading, "bye"
    assert_accessible_name greet, "greet"
    refute_accessible_name greet, "send"
  end

  def test_value_attribute_count
    name_field.fill("Ada")
    assert_value name_field, "Ada"
    refute_value name_field, "Grace"
    assert_attribute name_field, "title", "your name"
    refute_attribute name_field, "title", "other"
    assert_count items, 3
    refute_count items, 2
  end

  # Ruby regexp syntax reaches e2e as the equivalent JavaScript regexp.
  def test_ruby_regexps
    assert_text heading, /\Asay hello\z/
    assert_text heading, /^SAY/i
    assert_text screen.get_by_test_id("port"), /\A\d+\z/
  end

  # A missing stored screenshot is written and the matcher fails (e2e's rule), so the
  # first run proves the matcher reaches e2e; refute_ inverts it.
  def test_screenshot
    error = assert_raises(Minitest::Assertion) { assert_screenshot heading, "heading-#{Process.pid}" }
    assert_match(/screenshot/i, error.message)
  end
end
