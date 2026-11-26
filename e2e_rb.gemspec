# frozen_string_literal: true

require_relative "lib/e2e_rb/version"

Gem::Specification.new do |spec|
  spec.name = "e2e_rb"
  spec.version = E2eRb::VERSION
  spec.summary = "RSpec and Minitest tests on top of e2e, the agentic end-to-end testing framework"
  spec.description = "Drives e2e (npm package `e2e`) from Ruby: agent.act / agent.assert plus " \
                     "auto-waiting locators and expect, through a Node bridge that hosts e2e sessions."
  spec.authors = ["e2e_rb contributors"]
  spec.homepage = "https://github.com/robertziel/e2e_rb"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*.rb", "bridge/*.mjs", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }
end
