#!/bin/sh
# The deterministic suite, run inside the test image (compose service `test`, no network).
# Every step must pass; nothing is skipped.
set -eu
cd /gem

step() { printf '\n=== %s\n' "$*"; }

step "bridge: syntax + node unit tests"
for f in bridge/*.mjs bridge/test/*.mjs; do node --check "$f"; done
node --test bridge/test/*.test.mjs

step "rubocop"
bundle exec rubocop

step "unit specs"
bundle exec rspec spec

step "RSpec examples (browser, no model)"
bundle exec rspec example/spec/greeting_spec.rb example/spec/no_model_spec.rb \
  example/spec/matchers_drift_spec.rb example/spec/reporting_spec.rb \
  example/spec/model_config_spec.rb

step "Minitest examples (browser, no model), one process"
bundle exec ruby -Ilib -e 'ARGV.each { |f| require File.expand_path(f) }' \
  example/test/greeting_test.rb example/test/matchers_test.rb example/test/no_model_test.rb example/test/fork_test.rb

step "parallel worker processes"
bundle exec ruby scripts/parallel_workers.rb 4

step "the built gem, installed, outside the checkout"
gem build e2e_rb.gemspec --output /tmp/e2e_rb.gem
GEM_HOME=/tmp/e2e_rb-gems gem install --local --no-document /tmp/e2e_rb.gem
# Not bundler, not -Ilib: the installed gem plus the image's gems (every dir of its gem path).
image_gems=$(gem env gempath)
(cd /tmp && GEM_HOME=/tmp/e2e_rb-gems GEM_PATH="/tmp/e2e_rb-gems:$image_gems" ruby -e '
  require "e2e_rb"
  path = $LOADED_FEATURES.grep(%r{/e2e_rb\.rb\z}).first
  abort "e2e_rb loaded from #{path}, not the installed gem" unless path.start_with?("/tmp/e2e_rb-gems/")
  abort "the installed gem has no bridge" unless File.file?(E2eRb::Bridge::SERVER)
  puts "installed gem: #{path}"
  load "/gem/example/test/greeting_test.rb"
')
