# frozen_string_literal: true

require "open3"

module E2eRb
  # One Node bridge process: spawn, request/response, notifications, shutdown.
  class Bridge
    SERVER = File.expand_path("../../bridge/server.mjs", __dir__)

    attr_reader :e2e_version, :pid

    def initialize(node:, cwd:, on_notification:)
      @cwd = cwd
      @on_notification = on_notification
      @next_id = 0
      @mutex = Mutex.new
      spawn(node)
      handshake
    end

    def request(method, params = {})
      @mutex.synchronize do
        @next_id += 1
        id = @next_id
        @wire.write("id" => id, "method" => method, "params" => params)
        loop do
          message = @wire.read
          raise BridgeError, "e2e bridge exited during #{method}: #{exit_status}" if message.nil?

          if message.key?("method") && !message.key?("id")
            @on_notification.call(message["method"], message["params"])
            next
          end
          raise BridgeError, "bridge answered request #{message["id"]}, expected #{id}" unless message["id"] == id

          return message["result"] unless message.key?("error")

          yield_error = block_given? ? yield(message["error"]) : nil
          raise(yield_error || E2eRb.error_from_wire(message["error"]))
        end
      end
    end

    def shutdown
      return if @stdin.closed?

      begin
        request("shutdown")
      rescue BridgeError, IOError, Errno::EPIPE
        # The process is gone already; the wait below reports how it ended.
      end
      @stdin.close unless @stdin.closed?
      @thread.join
    end

    def alive? = @thread.alive?

    private

    def spawn(node)
      read_out, @write_out = IO.pipe
      @stdin, @thread = begin
        stdin_r, stdin_w = IO.pipe
        pid = Process.spawn(node, SERVER, in: stdin_r, 3 => @write_out, out: $stderr, err: $stderr, chdir: @cwd)
        stdin_r.close
        @write_out.close
        @pid = pid
        [stdin_w, Process.detach(pid)]
      rescue Errno::ENOENT
        raise BridgeError, "cannot start the e2e bridge: #{node.inspect} not found (set E2E_RB_NODE)"
      end
      @wire = Wire.new(read_out, @stdin)
    end

    def handshake
      result = request("initialize", "protocolVersion" => PROTOCOL_VERSION, "cwd" => @cwd)
      @e2e_version = result.fetch("e2eVersion")
      return if E2E_REQUIREMENT.satisfied_by?(Gem::Version.new(@e2e_version))

      shutdown
      raise BridgeError, "e2e #{@e2e_version} is installed in #{@cwd}; e2e_rb #{VERSION} needs e2e #{E2E_REQUIREMENT}"
    end

    def exit_status
      @thread.join(5)
      status = @thread.value if !@thread.alive?
      status ? "exit #{status.exitstatus || "signal #{status.termsig}"}" : "still running"
    end
  end
end
