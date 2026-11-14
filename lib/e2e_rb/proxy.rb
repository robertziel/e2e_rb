# frozen_string_literal: true

module E2eRb
  # A remote e2e object: a fixture root (app, screen, agent, ...) plus a call chain.
  # Every method call goes to the bridge, which re-applies the chain in Node.
  # Builders (get_by_role, first, filter, ...) come back as new proxies;
  # actions (click, fill, act, ...) come back as values.
  #
  # A BasicObject, so Locator#tap, #select_option etc. never hit Object's methods.
  class Proxy < BasicObject
    def initialize(session, root, chain = [])
      @session = session
      @root = root
      @chain = chain
    end

    def method_missing(name, *positional, **options, &block)
      # Ruby's implicit conversions (to_ary, to_str, ...) are never e2e calls.
      ::Kernel.raise ::NoMethodError.new("undefined method '#{name}' for #{inspect}", name) if name.start_with?("to_")
      ::Kernel.raise ::ArgumentError, "e2e calls take no block (#{name})" if block

      step = { "m" => Codec.js_name(name), "a" => Codec.args(positional, options) }
      result = @session.invoke(@root, @chain + [step])
      case result["kind"]
      when "locator"
        Proxy.new(@session, @root, @chain + [step])
      when "locators"
        ::Array.new(result.fetch("count")) do |index|
          Proxy.new(@session, @root, @chain + [{ "m" => "nth", "a" => [index] }])
        end
      else
        result["value"]
      end
    end

    # Ruby duck-typing probes (respond_to?(:to_ary), :call, ...) must not reach e2e.
    def respond_to?(name, _include_all = false) = name.to_s.start_with?("__e2e_")

    def __e2e_wire__ = { "$locator" => { "root" => @root, "chain" => @chain } }
    def __e2e_session__ = @session
    def __e2e_subject__ = { "root" => @root, "chain" => @chain }

    def is_a?(klass) = klass == Proxy
    alias kind_of? is_a?
    def class = Proxy
    def nil? = false

    def inspect
      calls = @chain.map { |step| "#{step["m"]}(#{step["a"].map { |a| ::JSON.generate(a) }.join(", ")})" }
      "#<e2e #{[@root, *calls].join(".")}>"
    end
    alias to_s inspect
  end
end
