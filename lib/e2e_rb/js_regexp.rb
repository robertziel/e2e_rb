# frozen_string_literal: true

module E2eRb
  # A Ruby Regexp as the JavaScript regexp that matches the same strings, read by the
  # bridge as `new RegExp(source, flags)` (no `u` flag). What JavaScript cannot express
  # raises ArgumentError instead of silently matching something else.
  class JsRegexp
    # Ruby escapes with a JS equivalent (outside a character class).
    ESCAPES = {
      "A" => "(?<![\\s\\S])",          # start of string
      "z" => "(?![\\s\\S])",           # end of string
      "Z" => "(?=\\n?(?![\\s\\S]))", # end of string, before a final newline
      "h" => "[0-9a-fA-F]",
      "H" => "[^0-9a-fA-F]"
    }.freeze
    # Ruby escapes JS reads differently or not at all: \p{..} \g<..> \e \a \C- \M- ...
    RUBY_ONLY_ESCAPES = %w[G K R X p P g e a C M].freeze
    # Ruby groups JS lacks: atomic, absent, comment, quoted name, conditional, inline options.
    RUBY_ONLY_GROUP = /\A\(\?(?:>|~|#|'|\(|[imx-]+[:)])/

    attr_reader :source, :flags

    def initialize(regexp)
      @regexp = regexp
      @flags = translate_flags
      @source = translate_source
    end

    def to_wire = { "source" => source, "flags" => flags }

    private

    # `m` always: Ruby's ^ and $ are line anchors. Ruby's /m (dot matches newline) is JS's `s`.
    def translate_flags
      refuse("JavaScript regexps have no extended (x) mode") if option?(Regexp::EXTENDED)
      flags = +"m"
      flags << "i" if option?(Regexp::IGNORECASE)
      flags << "s" if option?(Regexp::MULTILINE)
      flags
    end

    def option?(flag) = @regexp.options.anybits?(flag)

    def translate_source
      @in = @regexp.source
      @out = +""
      @at = 0
      @in_class = false
      step while @at < @in.length
      @out
    end

    def step
      char = @in[@at]
      if char == "\\" then escape
      elsif @in_class then class_char(char)
      elsif char == "[" then open_class
      else
        refuse_group if char == "("
        emit(char, 1)
      end
    end

    def emit(text, width)
      @out << text
      @at += width
    end

    # `[` / `[^`, then a `]` right after it: in Ruby a literal `]`, in JS an empty class.
    def open_class
      @in_class = true
      emit("[", 1)
      emit("^", 1) if @in[@at] == "^"
      emit("\\]", 1) if @in[@at] == "]"
    end

    def class_char(char)
      refuse("JavaScript regexps have no class intersection (&&)") if @in[@at, 2] == "&&"
      refuse("JavaScript regexps have no nested or POSIX ([:alpha:]) classes") if char == "["
      @in_class = false if char == "]"
      emit(char, 1)
    end

    def refuse_group
      refuse("JavaScript regexps have no #{Regexp.last_match(0)} group") if @in[@at..] =~ RUBY_ONLY_GROUP
    end

    def escape
      escaped = @in[@at + 1]
      refuse("regexp ends in a backslash") if escaped.nil?
      refuse("JavaScript regexps have no \\#{escaped}") if RUBY_ONLY_ESCAPES.include?(escaped)
      refuse("JavaScript regexps have no \\u{...}") if escaped == "u" && @in[@at + 2] == "{"
      emit(@in_class ? class_escape(escaped) : ESCAPES.fetch(escaped, "\\#{escaped}"), 2)
    end

    def class_escape(escaped)
      refuse("\\H inside a character class has no JavaScript form") if escaped == "H"
      escaped == "h" ? "0-9a-fA-F" : "\\#{escaped}"
    end

    def refuse(reason)
      raise ArgumentError, "#{reason}: #{@regexp.inspect}"
    end
  end
end
