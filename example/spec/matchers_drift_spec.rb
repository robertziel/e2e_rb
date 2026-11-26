# frozen_string_literal: true

require "e2e_rb"

# E2eRb::MATCHERS must list exactly e2e's locator + screen matchers, read from the
# installed e2e's own type declarations, so an e2e upgrade that adds or drops one fails here.
RSpec.describe "E2eRb::MATCHERS" do
  it "matches the matchers the installed e2e declares" do
    types = File.read(File.join(ENV.fetch("E2E_RB_PROJECT_DIR"), "node_modules/e2e/dist/types.d.ts"))
    declared = %w[AsyncExpectation ScreenExpectation].flat_map do |interface|
      body = types[/^export interface #{interface} \{\n(.*?)^\}/m,
                   1] or raise "e2e's types.d.ts has no interface #{interface}"
      body.scan(/^    (to[A-Z]\w*)\(/).flatten
    end
    expect(E2eRb::MATCHERS.map { |row| row[:e2e] }.sort).to eq(declared.uniq.sort)
  end
end
