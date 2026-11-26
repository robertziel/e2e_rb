# frozen_string_literal: true

require "json"
require "open3"

# Test doubles and helpers for the unit specs.
module E2eRbSpec
  # A bridge wire scripted by a block: each written request is answered by the block's
  # reply (a Hash, an Array of messages, or nil for "answered later" via #push).
  class FakeWire
    attr_reader :written

    def initialize(&responder)
      @responder = responder
      @written = []
      @inbox = Queue.new
    end

    def write(message)
      @written << message
      reply = @responder.call(message)
      (reply.is_a?(Array) ? reply : [reply].compact).each { |inner| @inbox << inner }
    end

    def read = @inbox.pop
    def push(message) = @inbox << message

    def self.initialize_reply(message) = { "id" => message["id"], "result" => { "e2eVersion" => "0.23.1" } }

    # Answers every request at once with {"ok" => method}, except "slow": the block gets it, to answer later.
    def self.holding_slow(&hold)
      new do |message|
        case message["method"]
        when "initialize" then initialize_reply(message)
        when "slow" then hold.call(message) && nil
        else { "id" => message["id"], "result" => { "ok" => message["method"] } }
        end
      end
    end
  end

  # A bridge whose host/close answer (or exception) comes from a block; records calls.
  class ScriptedBridge
    attr_reader :calls

    def initialize(&on_close)
      @on_close = on_close
      @calls = []
    end

    def request(method, _params = {})
      @calls << method
      @on_close.call
    end

    def shutdown = @calls << :shutdown
    def reap = @calls << :reap
  end

  # A session that records each invoke(root, chain) and answers by the chain's last call.
  class RecordingSession
    ANSWERS = {
      "getByRole" => { "kind" => "locator" }, "first" => { "kind" => "locator" },
      "all" => { "kind" => "locators", "count" => 2 }, "count" => { "kind" => "value", "value" => 3 }
    }.freeze

    def initialize(calls) = @calls = calls

    def invoke(root, chain)
      @calls << [root, chain]
      ANSWERS.fetch(chain.last["m"], { "kind" => "value", "value" => nil })
    end
  end

  # Ruby regexp => strings: JsRegexp's output must match exactly what Ruby matches.
  JS_REGEXP_CASES = {
    /\Asay hello\z/ => ["say hello", "say hello\n", "x say hello", "say hello!"],
    /\Asay hello\Z/ => ["say hello", "say hello\n", "say hello\n\n"],
    /^hello$/ => %W[hello a\nhello\nb ahello],
    /\h+\z/ => %w[cafe beef1 xyz],
    /[\h-]+/ => ["--", "g"],
    /\H/ => %w[abc aXc],
    /a.b/m => %W[a\nb axb],
    /a.b/ => %W[a\nb axb],
    /HELLO/i => ["hello"],
    /\\A/ => ["\\A", "A"],
    /[\]A]/ => ["]", "A", "x"],
    /[^]a]/ => ["]", "a", "b", "]a"],
    /[^]\h]/ => ["]", "f", "z"],
    /A/ => %w[A u0041],
    /\x41\d\w\s\b/ => ["A1_ ", "A1_x"],
    /(a)\1/ => %w[aa ab],
    /(?<n>a)\k<n>/ => %w[aa ab],
    /(?<word>\w+)!/ => ["hey!", "!"]
  }.freeze

  NODE_TEST = "const rows = JSON.parse(require('fs').readFileSync(0, 'utf8'));" \
              "process.stdout.write(JSON.stringify(rows.map(([s, f, str]) => new RegExp(s, f).test(str))));"

  # [source, flags, string] rows -> whether `new RegExp(source, flags).test(string)` in Node.
  def self.node_matches(rows)
    out, status = Open3.capture2("node", "-e", NODE_TEST, stdin_data: JSON.generate(rows))
    raise "node failed: #{out}" unless status.success?

    JSON.parse(out)
  end
end
