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

      chain = @chain + [{ "m" => Codec.js_name(name), "a" => Codec.args(positional, options) }]
      __e2e_result__(@session.invoke(@root, chain), chain)
    end

    # Ruby duck-typing probes (respond_to?(:to_ary), :call, ...) must not reach e2e:
    # a proxy claims only its own __e2e_* methods.
    def respond_to_missing?(name, _include_all) = name.to_s.start_with?("__e2e_")
    def respond_to?(name, *) = respond_to_missing?(name, false)

    def __e2e_wire__ = { "$locator" => { "root" => @root, "chain" => @chain } }
    def __e2e_session__ = @session
    def __e2e_subject__ = { "root" => @root, "chain" => @chain }

    # Two proxies are equal when they name the same expression in the same session,
    # so they work as Hash keys and in Array#include? without a round trip.
    def ==(other)
      other.is_a?(Proxy) && other.__e2e_session__.equal?(@session) && other.__e2e_subject__ == __e2e_subject__
    end
    alias eql? ==
    def hash = [Proxy, @session.__id__, @root, @chain].hash

    def is_a?(klass) = klass == Proxy
    alias kind_of? is_a?
    def class = Proxy
    def nil? = false

    # A builder's result is a new proxy; all() a list of nth() proxies; an action's, its value.
    def __e2e_result__(result, chain)
      case result["kind"]
      when "locator" then Proxy.new(@session, @root, chain)
      when "locators" then ::Array.new(result.fetch("count")) { |index| __e2e_nth__(chain, index) }
      else result["value"]
      end
    end

    def inspect
      calls = @chain.map { |step| "#{step["m"]}(#{step["a"].map { |a| ::JSON.generate(a) }.join(", ")})" }
      "#<e2e #{[@root, *calls].join(".")}>"
    end
    alias to_s inspect

    def __e2e_nth__(chain, index) = Proxy.new(@session, @root, chain[0...-1] + [{ "m" => "nth", "a" => [index] }])
  end
end
