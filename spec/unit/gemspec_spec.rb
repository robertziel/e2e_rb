# frozen_string_literal: true

require "rubygems"

# The gemspec as RubyGems loads it, from the repo root.
module GemspecSpec
  ROOT = File.expand_path("../..", __dir__)
  SPEC = Dir.chdir(ROOT) { Gem::Specification.load("e2e_rb.gemspec") }
end

RSpec.describe "e2e_rb.gemspec: RubyGems' rules" do
  root = GemspecSpec::ROOT
  spec = GemspecSpec::SPEC

  # Strict: every RubyGems warning (`gem build` prints them) fails, packaging checks included.
  it "passes RubyGems' own validation, strict, with no warnings" do
    Dir.chdir(root) do
      expect { spec.validate(true, true) }.not_to raise_error
    end
  end

  # RubyGems' naming rule: underscores, `require "e2e_rb"`, module E2eRb (guides.rubygems.org/name-your-gem).
  it "is named so that require and the constant follow from the gem name" do
    expect(spec.name).to match(/\A[a-z0-9_]+\z/)
    expect(File).to exist(File.join(root, "lib", "#{spec.name}.rb"))
    expect(spec.name.split("_").map(&:capitalize).join).to eq(E2eRb.name)
  end

  it "has a summary, a longer description, authors and a homepage" do
    expect(spec.summary).not_to be_empty
    expect(spec.description).not_to eq(spec.summary)
    expect(spec.authors).not_to be_empty
    expect(spec.homepage).to start_with("https://")
  end
end

RSpec.describe "e2e_rb.gemspec: contents and metadata" do
  root = GemspecSpec::ROOT
  spec = GemspecSpec::SPEC

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
