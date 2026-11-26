# frozen_string_literal: true

module E2eRb
  # One Node bridge process: spawn, request/response, notifications, shutdown.
  class Bridge
    SERVER = File.expand_path("../../bridge/server.mjs", __dir__)
    # How long a bridge may take to exit after `shutdown` / end of input before it is killed.
    EXIT_GRACE_SECONDS = 10

    attr_reader :e2e_version, :pid

    # wire: injected by unit specs; otherwise a node process is spawned.
    def initialize(node:, cwd:, on_notification:, wire: nil, process: nil)
      @cwd = cwd
      @on_notification = on_notification
      @next_id = 0
      @mutex = Mutex.new
      wire ? use(wire, process) : spawn(node)
      handshake
    rescue StandardError
      kill if @pid
      raise
    end

    # Sends one request and returns its result. A request abandoned by an exception
    # (Timeout, Interrupt) leaves its reply in the pipe; the next request skips it.
    # The block, if given, builds the exception for an error reply.
    def request(method, params = {}, &on_error)
      @mutex.synchronize do
        id = (@next_id += 1)
        @wire.write("id" => id, "method" => method, "params" => params)
        reply = read_reply(id, method)
        return reply["result"] unless reply.key?("error")

        raise(on_error&.call(reply["error"]) || E2eRb.error_from_wire(reply["error"]))
      end
    end

    # Asks the bridge to exit and waits for it; kills it after EXIT_GRACE_SECONDS.
    def shutdown
      return if @stdin.nil? || @stdin.closed?

      begin
        request("shutdown")
      rescue BridgeError, IOError, SystemCallError
        # The process is gone already; the wait below reports how it ended.
      end
      reap
    end

    # Closes our end of the pipe (the bridge then closes its host and exits) and waits
    # a bounded time; kills it if it does not exit. Never raises: for at_exit.
    def reap
      @stdin.close unless @stdin.nil? || @stdin.closed?
      @reader.close unless @reader.nil? || @reader.closed?
      kill unless @thread.nil? || @thread.join(EXIT_GRACE_SECONDS)
    end

    # In a forked child: drop the parent's pipe ends without touching the parent's bridge,
    # so the parent's bridge sees end of input when the parent closes them.
    def close_inherited
      [@stdin, @reader].each { |io| io.close if io && !io.closed? }
    end

    def alive? = @thread.alive?

    private

    def use(wire, process)
      @wire = wire
      @thread = process
    end

    # The reply to request `id`: notifications on the way are delivered, replies to
    # abandoned (earlier) requests skipped.
    def read_reply(id, method)
      loop do
        message = @wire.read
        raise BridgeError, "e2e bridge exited during #{method}: #{exit_status}" if message.nil?
        next notify(message) if notification?(message)
        next if stale?(message["id"], id)
        return message if message["id"] == id

        raise BridgeError, "bridge answered request #{message["id"].inspect}, expected #{id}"
      end
    end

    def notification?(message) = message.key?("method") && !message.key?("id")
    def notify(message) = @on_notification.call(message["method"], message["params"])
    def stale?(reply_id, id) = reply_id.is_a?(Integer) && reply_id < id

    def spawn(node)
      @reader, write_out = IO.pipe
      stdin_r, @stdin = IO.pipe
      @pid = start_process(node, stdin_r, write_out)
      @thread = Process.detach(@pid)
      @wire = Wire.new(@reader, @stdin)
    end

    # node server.mjs: requests on stdin, the protocol out on fd 3, its own output on our stderr.
    def start_process(node, stdin_r, write_out)
      Process.spawn(node, SERVER, in: stdin_r, 3 => write_out, out: $stderr, err: $stderr, chdir: @cwd)
    rescue Errno::ENOENT
      raise BridgeError, "cannot start the e2e bridge: #{node.inspect} not found (set E2E_RB_NODE)"
    ensure
      stdin_r.close
      write_out.close
    end

    def kill
      return unless @pid && @thread&.alive?

      Process.kill("TERM", @pid)
      Process.kill("KILL", @pid) unless @thread.join(EXIT_GRACE_SECONDS)
      @thread.join
    rescue Errno::ESRCH
      # Already gone.
    end

    def handshake
      result = request("initialize", "protocolVersion" => PROTOCOL_VERSION, "cwd" => @cwd)
      @e2e_version = result.fetch("e2eVersion")
      return if E2E_REQUIREMENT.satisfied_by?(Gem::Version.new(@e2e_version))

      raise BridgeError, "e2e #{@e2e_version} is installed in #{@cwd}; e2e_rb #{VERSION} needs e2e #{E2E_REQUIREMENT}"
    end

    def exit_status
      return "unknown (no process)" if @thread.nil?

      @thread.join(5)
      status = @thread.value unless @thread.alive?
      status ? "exit #{status.exitstatus || "signal #{status.termsig}"}" : "still running"
    end
  end
end
