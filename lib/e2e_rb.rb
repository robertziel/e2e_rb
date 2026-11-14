# frozen_string_literal: true

require "json"
require_relative "e2e_rb/version"
require_relative "e2e_rb/errors"
require_relative "e2e_rb/wire"
require_relative "e2e_rb/codec"
require_relative "e2e_rb/proxy"
require_relative "e2e_rb/bridge"
require_relative "e2e_rb/session"
require_relative "e2e_rb/runtime"

# Ruby tests on top of e2e (https://e2e.com): agentic steps plus locators and
# expect, driven through a Node bridge that hosts e2e sessions.
module E2eRb
  class << self
    def configuration = @configuration ||= Configuration.new

    def configure
      raise Error, "configure E2eRb before the first session opens" if @runtime

      yield configuration
    end

    def runtime = @runtime ||= Runtime.new(configuration).tap { |runtime| at_exit { runtime.shutdown } }

    # Opens one test attempt. Call #close on it when the test ends.
    def open_session(name:, **options) = runtime.open_session(name: name, **options)

    # A secret from e2e's config (E2E_SECRET_<NAME>); its value never enters Ruby.
    def secret(name) = SecretRef.new("$secret" => name.to_s)

    # A credential from e2e's config (E2E_USER_<NAME>_*): field :username or :password.
    def credential(name, field) = SecretRef.new("$credential" => name.to_s, "field" => field.to_s)
  end
end
