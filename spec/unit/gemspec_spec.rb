# frozen_string_literal: true

require "rubygems"

RSpec.describe "e2e_rb.gemspec" do
  root = File.expand_path("../..", __dir__)
  spec = Dir.chdir(root) { Gem::Specification.load("e2e_rb.gemspec") }

  it "passes RubyGems' own validation" do
    Dir.chdir(root) { expect { spec.validate(false) }.not_to raise_error }
  end

  it "ships the bridge, every library file, the license and the changelog" do
    Dir.chdir(root) do
      expect(spec.files).to include("bridge/server.mjs", "bridge/node-range.mjs", "LICENSE", "README.md",
                                    "CHANGELOG.md")
      expect(spec.files).to include(*Dir["lib/**/*.rb"])
      expect(spec.files.grep(%r{\A(spec|example|bridge/test)/})).to be_empty
    end
  end

  it "points at the source, changelog and issues, and requires MFA to push" do
    expect(spec.license).to eq("Apache-2.0")
    expect(spec.metadata.keys).to include("source_code_uri", "changelog_uri", "bug_tracker_uri")
    expect(spec.metadata["rubygems_mfa_required"]).to eq("true")
  end

  it "has a changelog entry for its version" do
    expect(File.read(File.join(root, "CHANGELOG.md"))).to include("## [#{spec.version}]")
  end
end
