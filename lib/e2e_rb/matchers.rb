# frozen_string_literal: true

module E2eRb
  # e2e's locator / screen matchers (AsyncExpectation + ScreenExpectation in e2e's
  # types.d.ts), one row each, with the names the adapters give them:
  #   rspec:    expect(locator).to be_visible
  #   minitest: assert_visible(locator) / refute_visible(locator)
  # Both adapters are generated from this table; example/spec/matchers_drift_spec.rb
  # fails when e2e adds or drops a matcher.
  MATCHERS = [
    { e2e: "toBeVisible",          rspec: :be_visible,           minitest: :visible },
    { e2e: "toBeHidden",           rspec: :be_hidden,            minitest: :hidden },
    { e2e: "toBeAttached",         rspec: :be_attached,          minitest: :attached },
    { e2e: "toBeEnabled",          rspec: :be_enabled,           minitest: :enabled },
    { e2e: "toBeDisabled",         rspec: :be_disabled,          minitest: :disabled },
    { e2e: "toBeChecked",          rspec: :be_checked,           minitest: :checked },
    { e2e: "toBeSelected",         rspec: :be_selected,          minitest: :selected },
    { e2e: "toBeExpanded",         rspec: :be_expanded,          minitest: :expanded },
    { e2e: "toBeFocused",          rspec: :be_focused,           minitest: :focused },
    { e2e: "toHaveText",           rspec: :have_text,            minitest: :text },
    { e2e: "toContainText",        rspec: :contain_text,         minitest: :contains_text },
    { e2e: "toHaveValue",          rspec: :have_value,           minitest: :value },
    { e2e: "toHaveAttribute",      rspec: :have_attribute,       minitest: :attribute },
    { e2e: "toHaveCount",          rspec: :have_count,           minitest: :count },
    { e2e: "toHaveAccessibleName", rspec: :have_accessible_name, minitest: :accessible_name },
    { e2e: "toHaveScreenshot",     rspec: :have_screenshot,      minitest: :screenshot }
  ].each(&:freeze).freeze
end
