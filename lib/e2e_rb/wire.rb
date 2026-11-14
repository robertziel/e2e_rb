# frozen_string_literal: true

require "json"

module E2eRb
  # JSON-RPC 2.0 messages with LSP framing (Content-Length headers).
  class Wire
    def initialize(reader, writer)
      @reader = reader
      @writer = writer
    end

    def write(message)
      body = JSON.generate(message.merge("jsonrpc" => "2.0"))
      @writer.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
      @writer.flush
    end

    # Returns the next message, or nil at end of stream.
    def read
      length = nil
      loop do
        line = @reader.gets("\r\n")
        return nil if line.nil?

        line = line.chomp("\r\n")
        break if line.empty?

        name, value = line.split(":", 2)
        length = Integer(value.strip) if name.strip.casecmp?("Content-Length")
      end
      raise BridgeError, "bridge sent a frame without Content-Length" if length.nil?

      body = @reader.read(length)
      raise BridgeError, "bridge closed mid-frame" if body.nil? || body.bytesize < length

      JSON.parse(body.force_encoding(Encoding::UTF_8))
    end
  end
end
