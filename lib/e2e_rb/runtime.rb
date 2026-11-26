# frozen_string_literal: true

module E2eRb
  # Per-process state: one bridge, one host, at most one open session.
  # A forked worker starts its own bridge; a separately spawned worker process
  # (one Ruby process per test file) has its own runtime anyway.
  class Runtime
    ONE_SESSION = "e2e allows one per process (use process parallelism, not threads)"

    attr_reader :bridge

    def initialize(configuration)
      @configuration = configuration
      @pid = Process.pid
      @session = nil
    end

    def open_session(name:, failure_class: TestFailure, timeout: @configuration.timeout, agent: nil)
      ensure_host
      raise Error, "session #{@session.name.inspect} is still open; #{ONE_SESSION}" if @session

      info = @bridge.request("session/open", "name" => name, "timeout" => timeout, "agent" => agent)
      @session = Session.new(self, name: name, info: info, failure_class: failure_class)
    end

    def close_session(session)
      return close_open_session if @session.equal?(session)

      raise Error, "closing #{session.name.inspect}, but #{@session&.name.inspect} is open"
    end

    # Closes the host (stops the app, the engine) and the bridge. Called by the
    # adapters at the end of the suite; raises InfrastructureError with the reason
    # when e2e reports a close failure or the bridge died, so the run fails.
    def close!
      return unless @bridge && @pid == Process.pid

      bridge = @bridge
      host_open = @host_open
      forget_bridge
      failures = host_open ? close_host(bridge) : []
      bridge.shutdown
      return if failures.empty?

      raise InfrastructureError, "e2e host close failed: #{failures.map { |f| f["message"] }.join("; ")}"
    end

    # Last resort at process exit: ends the bridge without raising (the bridge
    # closes its host when its input ends). The adapters' close! reports failures.
    def reap
      return unless @bridge && @pid == Process.pid

      @bridge.reap
      forget_bridge
    end

    private

    def close_open_session
      @session = nil
      @bridge.request("session/close")
    end

    # e2e's close failures. A dead bridge, or an error e2e raises, is a failure too.
    def close_host(bridge)
      bridge.request("host/close").fetch("failures")
    rescue BridgeError, IOError, SystemCallError => e
      bridge.reap
      raise InfrastructureError, "e2e host close failed: the bridge is gone (#{e.message})"
    rescue Error => e
      bridge.shutdown
      raise InfrastructureError, "e2e host close failed: #{e.message}"
    end

    def forget_bridge
      @bridge = nil
      @host_open = false
    end

    def ensure_host
      reset_after_fork if @pid != Process.pid
      return if @host_open

      @bridge ||= Bridge.new(node: @configuration.node, cwd: @configuration.project_root,
                             on_notification: method(:notification))
      @bridge.request("host/open", "config" => @configuration.config, "target" => @configuration.target,
                                   "headed" => @configuration.headed)
      @host_open = true
    end

    # The parent's bridge belongs to the parent: the child drops its copies of the
    # pipe ends (so the parent's bridge still sees end of input when the parent
    # exits) and starts its own.
    def reset_after_fork
      @bridge&.close_inherited
      @pid = Process.pid
      forget_bridge
      @session = nil
    end

    def notification(method, params)
      case method
      when "step" then @configuration.on_step&.call(params)
      when "notice" then @configuration.on_notice&.call(params["target"], params["message"])
      end
    end
  end
end
