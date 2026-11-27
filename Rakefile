# frozen_string_literal: true

# `rake` runs the unit specs and RuboCop; `rake build` packages the gem into pkg/ with `gem build --strict`
# (any RubyGems warning fails); `rake install` installs that package. There is no `release` task on purpose:
# a release is tagged and pushed by a maintainer, never from a development checkout. The browser examples
# need the e2e project and Chromium: scripts/ci/suite.sh runs them in the test image.
require "rspec/core/rake_task"
require "rubocop/rake_task"

GEMSPEC = Gem::Specification.load(File.expand_path("e2e_rb.gemspec", __dir__))
PACKAGE = "pkg/#{GEMSPEC.file_name}".freeze

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/**/*_spec.rb"
end

RuboCop::RakeTask.new

desc "Build #{PACKAGE} (gem build --strict)"
task :build do
  mkdir_p "pkg"
  sh "gem", "build", "--strict", "e2e_rb.gemspec", "--output", PACKAGE
end

desc "Build and install #{PACKAGE}"
task install: :build do
  sh "gem", "install", "--local", "--no-document", PACKAGE
end

task default: %i[spec rubocop]
