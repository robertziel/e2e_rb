# frozen_string_literal: true

module E2eRb
  # Ruby values -> wire values for call arguments.
  module Codec
    module_function

    # snake_case Ruby names -> camelCase e2e names. `visible?` -> `isVisible`.
    def js_name(name)
      name = name.to_s
      raise ArgumentError, "e2e has no bang methods: #{name}" if name.end_with?("!")

      predicate = name.end_with?("?")
      name = name.delete_suffix("?")
      parts = name.split("_")
      camel = parts.first + parts.drop(1).map(&:capitalize).join
      predicate ? "is#{camel[0].upcase}#{camel[1..]}" : camel
    end

    # Positional args plus keyword options -> one JS argument list.
    def args(positional, options)
      list = positional.map { |value| encode(value) }
      list << encode_options(options) unless options.empty?
      list
    end

    def encode(value)
      case value
      when Hash then value.to_h { |key, inner| [key.to_s, encode(inner)] }
      when Array then value.map { |inner| encode(inner) }
      when Regexp then { "$regex" => { "source" => value.source, "flags" => regexp_flags(value) } }
      when Symbol then value.to_s
      when String, Integer, Float, true, false, nil then value
      else
        return value.__e2e_wire__ if value.respond_to?(:__e2e_wire__)

        raise ArgumentError, "cannot send #{value.class} to e2e"
      end
    end

    # Symbol keys of option hashes are Ruby-style (snake_case) and become camelCase.
    # `params:` holds the user's own placeholder names, which stay as written.
    def encode_options(options)
      options.to_h do |key, value|
        name = key.is_a?(Symbol) ? js_name(key) : key.to_s
        encoded = key.to_s == "params" ? encode(value) : (value.is_a?(Hash) ? encode_options(value) : encode(value))
        [name, encoded]
      end
    end

    def regexp_flags(regexp)
      flags = +""
      flags << "i" if regexp.options & Regexp::IGNORECASE != 0
      flags << "s" if regexp.options & Regexp::MULTILINE != 0
      raise ArgumentError, "JavaScript regexps have no extended (x) mode: #{regexp.inspect}" if regexp.options & Regexp::EXTENDED != 0

      flags
    end
  end

  # A secret or credential named in e2e's config; the value never enters Ruby.
  class SecretRef
    def initialize(wire) = @wire = wire
    def __e2e_wire__ = @wire
    def inspect = "#<E2eRb::SecretRef #{@wire.values.first}>"
  end
end
