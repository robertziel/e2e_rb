# frozen_string_literal: true

# How an existing Minitest suite adds e2e_rb: its own base class, plus the include.
require "minitest/autorun"
require "e2e_rb/minitest"
require_relative "support/app_test"

# Every browser test opens the example app's page first.
class BrowserTest < AppTest
  include E2eRb::Minitest

  def setup = app.open("/")
  def port = screen.get_by_test_id("port").text_content
end
