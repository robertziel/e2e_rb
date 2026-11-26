# frozen_string_literal: true

require "json"

module E2eRb
  # JSON-RPC 2.0 messages with LSP framing (Content-Length headers).
  #
  # A frame is written and read whole: an asynchronous exception (Timeout, Interrupt)
  # is held until the frame is done, so it can never leave half a frame in the pipe.
  # Waiting for the first byte of a frame stays interruptible.
  class Wire
    def initialize(reader, writer)
      @reader = reader
      @writer = writer
    end

    def write(message)
      body = JSON.generate(message.merge("jsonrpc" => "2.0"))
      Thread.handle_interrupt(Object => :never) do
        @writer.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
        @writer.flush
      end
    end

    # Returns the next message, or nil at end of stream.
    def read
      Thread.handle_interrupt(Object => :never) do
        first = Thread.handle_interrupt(Object => :immediate) { @reader.gets("\r\n") }
        read_rest(first)
      end
    end

    private

    # nil at end of stream, else the frame's parsed body.
    def read_rest(first)
      length = content_length(first)
      return nil if length == :eof

      read_body(length)
    end

    # Reads the header lines up to the blank one; :eof if the stream ends first.
    def content_length(line)
      length = nil
      until line.nil? || (line = line.chomp("\r\n")).empty?
        name, value = line.split(":", 2)
        length = Integer(value.strip) if name.strip.casecmp?("Content-Length")
        line = @reader.gets("\r\n")
      end
      return :eof if line.nil?

      length || raise(BridgeError, "bridge sent a frame without Content-Length")
    end

    def read_body(length)
      body = @reader.read(length)
      raise BridgeError, "bridge closed mid-frame" if body.nil? || body.bytesize < length

      JSON.parse(body.force_encoding(Encoding::UTF_8))
    end
  end
end
