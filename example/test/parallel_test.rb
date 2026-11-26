# frozen_string_literal: true

require_relative "test_helper"

# One worker of scripts/parallel_workers.rb. With its session open it waits at a
# barrier until every worker has its session open (so all N run at once, each with
# its own bridge and app), then drives its app and records bridge pid + app port.
class ParallelTest < BrowserTest
  BARRIER_SECONDS = 60

  def test_one_worker
    my_port = port
    wait_for_every_worker
    greet_as("worker #{Process.pid}")
    File.write(File.join(dir, "done-#{Process.pid}"), "#{E2eRb.runtime.bridge.pid} #{my_port}")
  end

  private

  def greet_as(name)
    screen.get_by_label("name").fill(name)
    screen.get_by_role("button", "greet").click
    assert_text screen.get_by_role("status"), "hello, #{name}!"
  end

  def dir = ENV.fetch("PARALLEL_TEST_DIR")
  def workers = Integer(ENV.fetch("PARALLEL_TEST_WORKERS"), 10)
  def ready = Dir[File.join(dir, "ready-*")].size
  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def wait_for_every_worker
    File.write(File.join(dir, "ready-#{Process.pid}"), "")
    deadline = now + BARRIER_SECONDS
    until ready == workers
      flunk "only #{ready} of #{workers} workers had a session open after #{BARRIER_SECONDS}s" if now > deadline
      sleep 0.05
    end
  end
end
