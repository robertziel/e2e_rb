# frozen_string_literal: true

module E2eRb
  # Settings. Each one is read from its env var unless set in E2eRb.configure.
  # Every value is validated: a malformed one, or an E2E_RB_* name this gem does
  # not know (a typo), raises ConfigurationError naming it. Nothing is guessed.
  class Configuration
    ENV_NAMES = %w[
      E2E_RB_PROJECT_DIR E2E_RB_CONFIG E2E_RB_TARGET E2E_RB_HEADED
      E2E_RB_NODE E2E_RB_TIMEOUT_MS E2E_RB_VERBOSE
    ].freeze

    # Directory with package.json + node_modules/e2e + e2e.config.ts.
    attr_reader :project_dir
    # e2e config file, relative to project_dir. nil: e2e's own discovery.
    attr_reader :config
    # Target name; required by e2e when the config declares several.
    attr_reader :target
    attr_reader :headed
    # Node executable.
    attr_reader :node
    # Session deadline in ms. nil: the config's timeout.
    attr_reader :timeout
    # Called with every e2e step progress event (Hash).
    attr_accessor :on_step
    # Called with host notices (target, message).
    attr_accessor :on_notice

    def initialize(env = ENV)
      refuse_unknown(env)
      read_paths(env)
      read_flags(env)
      @on_notice = ->(target, message) { warn "[e2e #{target}] #{message}" }
    end

    def project_dir=(value)
      @project_dir = non_empty("project_dir", value)
    end

    def config=(value)
      @config = optional(value) { non_empty("config", value) }
    end

    def target=(value)
      @target = optional(value) { non_empty("target", value) }
    end

    def headed=(value)
      @headed = flag_value("headed", value)
    end

    def node=(value)
      @node = non_empty("node", value)
    end

    def timeout=(value)
      @timeout = optional(value) { positive_integer("timeout", value) }
    end

    # The project directory, checked: it must hold the project's package.json.
    def project_root
      root = File.expand_path(project_dir)
      return root if File.file?(File.join(root, "package.json"))

      raise ConfigurationError, "#{root} has no package.json; " \
                                "set E2E_RB_PROJECT_DIR to the directory with e2e installed"
    end

    private

    def refuse_unknown(env)
      unknown = env.keys.grep(/\AE2E_RB_/) - ENV_NAMES
      return if unknown.empty?

      raise ConfigurationError, "unknown setting #{unknown.sort.join(", ")}; e2e_rb reads #{ENV_NAMES.join(", ")}"
    end

    # Documented conventions, not substitutes: the cwd (like bundler) and `node` from PATH.
    def read_paths(env)
      self.project_dir = env.fetch("E2E_RB_PROJECT_DIR", Dir.pwd)
      self.config = env["E2E_RB_CONFIG"]
      self.target = env["E2E_RB_TARGET"]
      self.node = env.fetch("E2E_RB_NODE", "node")
    end

    def read_flags(env)
      self.headed = flag(env, "E2E_RB_HEADED")
      timeout_ms = env["E2E_RB_TIMEOUT_MS"]
      self.timeout = optional(timeout_ms) { positive_integer("E2E_RB_TIMEOUT_MS", timeout_ms) }
      @on_step = flag(env, "E2E_RB_VERBOSE") ? method(:print_step) : nil
    end

    def optional(value) = value.nil? ? nil : yield

    def flag_value(name, value)
      return value if [true, false].include?(value)

      raise ConfigurationError, "#{name} must be true or false, got #{value.inspect}"
    end

    def flag(env, name)
      case env[name]
      when nil, "0" then false
      when "1" then true
      else raise ConfigurationError, "#{name} must be 0 or 1, got #{env[name].inspect}"
      end
    end

    def positive_integer(name, value)
      number = case value
               when Integer then value
               when String then Integer(value, 10, exception: false)
               end
      raise ConfigurationError, "#{name} must be a positive integer (ms), got #{value.inspect}" unless number&.positive?

      number
    end

    def non_empty(name, value)
      return value if value.is_a?(String) && !value.empty?

      raise ConfigurationError, "#{name} must be a non-empty string, got #{value.inspect}"
    end

    def print_step(step)
      return unless step["phase"] == "end"

      warn "[e2e] #{step["api"]} #{step["label"]}: #{step["status"]} " \
           "(#{step["durationMs"]}ms, #{step["modelCalls"]} model calls)"
    end
  end
end
