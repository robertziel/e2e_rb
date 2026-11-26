# frozen_string_literal: true

# Stands in for an existing suite's own base class: e2e_rb is added to it with an
# include, not by changing what the suite's tests inherit from.
class AppTest < Minitest::Test
  def app_helper = :from_the_suite
end
