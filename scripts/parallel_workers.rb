# frozen_string_literal: true

# Runs N copies of example/test/parallel_test.rb as separate Ruby processes at once,
# the way a suite runs one process per test file, and checks that every worker
# passed with all N sessions open at the same time (the test's barrier), each on its
# own bridge and its own app port. Usage: ruby scripts/parallel_workers.rb N
require "rbconfig"
require "tmpdir"

workers = Integer(ARGV.fetch(0) { abort "usage: ruby scripts/parallel_workers.rb N" }, 10)
abort "N must be at least 2 (is #{workers})" if workers < 2

Dir.mktmpdir("e2e_rb-parallel-") do |dir|
  root = File.expand_path("..", __dir__)
  env = { "PARALLEL_TEST_DIR" => dir, "PARALLEL_TEST_WORKERS" => workers.to_s }
  pids = Array.new(workers) do |index|
    Process.spawn(env, RbConfig.ruby, "-I#{root}/lib", "#{root}/example/test/parallel_test.rb",
                  out: File.join(dir, "worker-#{index}.out"), err: %i[child out])
  end
  statuses = pids.map { |pid| Process.wait2(pid).last }
  failed = statuses.each_index.reject { |index| statuses[index].success? }
  failed.each { |index| warn "worker #{index} failed:\n#{File.read(File.join(dir, "worker-#{index}.out"))}" }
  abort "#{failed.size} of #{workers} workers failed" unless failed.empty?

  rows = Dir[File.join(dir, "done-*")].map { |file| File.read(file).split }
  abort "expected #{workers} worker records, got #{rows.size}" unless rows.size == workers
  bridges = rows.map(&:first).uniq
  ports = rows.map(&:last).uniq
  abort "workers shared a bridge: #{rows.inspect}" unless bridges.size == workers
  abort "workers shared an app port: #{rows.inspect}" unless ports.size == workers

  puts "parallel: #{workers} workers passed with #{workers} sessions open at once, " \
       "#{bridges.size} bridges, app ports #{ports.sort.join(" ")}"
end
