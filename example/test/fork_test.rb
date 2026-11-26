# frozen_string_literal: true

require_relative "test_helper"

# A worker forked after the parent opened a session starts its own bridge and app,
# and leaves the parent's bridge alone.
class ForkTest < BrowserTest
  def test_a_forked_child_gets_its_own_bridge_and_app
    parent = [E2eRb.runtime.bridge.pid.to_s, port]
    child, status = run_child

    assert status.success?, "the forked child failed: #{status.inspect}"
    refute_equal parent[0], child[0], "the child must start its own bridge"
    refute_equal parent[1], child[1], "the child's app must listen on its own port"
    assert_parent_unharmed
  end

  private

  def assert_parent_unharmed
    assert E2eRb.runtime.bridge.alive?, "the parent's bridge must survive the child"
    assert_text screen.get_by_role("heading"), "say hello"
  end

  # Forks a child that opens its own session; returns its [bridge pid, app port] and exit status.
  def run_child
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      child_session(writer)
    end
    writer.close
    seen = reader.read.split
    [seen, Process.wait2(pid).last]
  end

  def child_session(writer)
    session = E2eRb.open_session(name: "forked child")
    session.app.open("/")
    report(writer, session)
    session.close
    E2eRb.close!
    exit!(0)
  rescue StandardError => e
    warn "child: #{e.class}: #{e.message}"
  ensure
    exit!(1) # reached only when the child did not finish (exit! skips ensure)
  end

  def report(writer, session)
    writer.puts [E2eRb.runtime.bridge.pid, session.screen.get_by_test_id("port").text_content].join(" ")
    writer.close
  end
end
