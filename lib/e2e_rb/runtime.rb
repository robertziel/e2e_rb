# frozen_string_literal: true

module E2eRb
  # Settings. Each one is read from its env var unless set in E2eRb.configure.
  class Configuration
    # Directory with package.json + node_modules/e2e + e2e.config.ts.
    attr_accessor :project_dir
    # e2e config file, relative to project_dir. nil: e2e's own discovery.
    attr_accessor :config
    # Target name; required by e2e when the config declares several.
    attr_accessor :target
    attr_accessor :headed
    # Node executable.
    attr_accessor :node
    # Session deadline in ms. nil: the config's timeout.
    attr_accessor :timeout
    # Called with every e2e step progress event (Hash).
    attr_accessor :on_step
    # Called with host notices (target, message).
    attr_accessor :on_notice

    def initialize(env = ENV)
      @project_dir = env.fetch("E2E_RB_PROJECT_DIR", Dir.pwd)
      @config = env["E2E_RB_CONFIG"]
      @target = env["E2E_RB_TARGET"]
      @headed = env["E2E_RB_HEADED"] == "1"
      @node = env.fetch("E2E_RB_NODE", "node")
      @timeout = env["E2E_RB_TIMEOUT_MS"]&.then { |value| Integer(value) }
      @on_step = env["E2E_RB_VERBOSE"] == "1" ? method(:print_step) : nil
      @on_notice = ->(target, message) { warn "[e2e #{target}] #{message}" }
    end

    private

    def print_step(step)
      return unless step["phase"] == "end"

      warn "[e2e] #{step["api"]} #{step["label"]}: #{step["status"]} (#{step["durationMs"]}ms, #{step["modelCalls"]} model calls)"
    end
  end

  # Per-process state: one bridge, one host, at most one open session.
  # A forked worker (parallel_tests, Minitest fork) starts its own bridge.
  class Runtime
    attr_reader :bridge

    def initialize(configuration)
      @configuration = configuration
      @pid = Process.pid
      @session = nil
    end

    def open_session(name:, timeout: @configuration.timeout, agent: nil)
      ensure_host
      raise Error, "session #{@session.name.inspect} is still open; e2e allows one per process (use process parallelism, not threads)" if @session

      info = @bridge.request("session/open", "name" => name, "timeout" => timeout, "agent" => agent)
      @session = Session.new(self, name: name, info: info)
    end

    def close_session(session)
      raise Error, "closing #{session.name.inspect}, but #{@session&.name.inspect} is open" unless @session.equal?(session)

      @session = nil
      @bridge.request("session/close")
    end

    def shutdown
      return unless @bridge && @pid == Process.pid

      result = @bridge.request("host/close") if @host_open
      @host_open = false
      @bridge.shutdown
      @bridge = nil
      failures = result ? result.fetch("failures") : []
      raise InfrastructureError, "e2e host close failed: #{failures.map { |f| f["message"] }.join("; ")}" unless failures.empty?
    end

    private

    def ensure_host
      reset_after_fork if @pid != Process.pid
      return if @host_open

      @bridge ||= Bridge.new(
        node: @configuration.node,
        cwd: File.expand_path(@configuration.project_dir),
        on_notification: method(:notification)
      )
      @bridge.request("host/open",
                      "config" => @configuration.config,
                      "target" => @configuration.target,
                      "headed" => @configuration.headed)
      @host_open = true
    end

    # The parent's bridge belongs to the parent; a forked child starts fresh.
    def reset_after_fork
      @pid = Process.pid
      @bridge = nil
      @host_open = false
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
