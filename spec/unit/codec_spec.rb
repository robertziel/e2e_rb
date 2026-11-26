# frozen_string_literal: true

require_relative "../../lib/e2e_rb"
require_relative "../support/doubles"

RSpec.describe E2eRb::Codec do
  it "maps Ruby names to e2e names" do
    expect(described_class.js_name(:get_by_role)).to eq("getByRole")
    expect(described_class.js_name(:visible?)).to eq("isVisible")
    expect(described_class.js_name(:to_have_text)).to eq("toHaveText")
    expect(described_class.js_name(:click)).to eq("click")
    expect { described_class.js_name(:click!) }.to raise_error(ArgumentError)
  end

  it "camelizes option keys but keeps params names as written" do
    args = described_class.args(["go {first_name}"], { params: { first_name: "Ada" }, max_steps: 3 })
    expect(args).to eq(["go {first_name}", { "params" => { "first_name" => "Ada" }, "maxSteps" => 3 }])
  end

  it "encodes secret references without values" do
    expect(described_class.encode(E2eRb.secret(:api_token))).to eq("$secret" => "api_token")
    expect(described_class.encode(E2eRb.credential(:admin, :password)))
      .to eq("$credential" => "admin", "field" => "password")
  end

  it "refuses values it cannot send" do
    expect { described_class.encode(Object.new) }.to raise_error(ArgumentError, /cannot send Object/)
  end
end

RSpec.describe E2eRb::JsRegexp do
  it "encodes regexps with their flags; m always, since Ruby's ^ and $ are line anchors" do
    expect(E2eRb::Codec.encode(/hello/i)).to eq("$regex" => { "source" => "hello", "flags" => "mi" })
    expect(E2eRb::Codec.encode(/a.b/m)).to eq("$regex" => { "source" => "a.b", "flags" => "ms" })
    expect { E2eRb::Codec.encode(/a b/x) }.to raise_error(ArgumentError, /extended/)
  end

  it "refuses Ruby regexp syntax JavaScript cannot express" do
    [/\Gx/, /a\Kb/, /\R/, /\X/, /(?>a)/, /(?i:a)b/, /(?i)a/, /[a-z&&[^b]]/, Regexp.new("[\\H]"),
     /\p{L}/, /\P{L}/, /\u{41}/, /(?<x>a)\g<x>/, /\e/, /\a/, /a(?#c)b/, /[[:alpha:]]/, Regexp.new("[a[b]]"),
     /(?'n'a)/, /(a)(?(1)b|c)/, Regexp.new('\C-a')].each do |regexp|
      expect { described_class.new(regexp) }
        .to raise_error(ArgumentError, /JavaScript|no JavaScript form/), regexp.inspect
    end
  end

  # The same regexp must match the same strings in Ruby and in Node (the JS engine
  # e2e runs it in). Node is on PATH in the test image.
  it "translates Ruby regexps so JavaScript matches exactly what Ruby matches" do
    rows = E2eRbSpec::JS_REGEXP_CASES.flat_map do |regexp, strings|
      js = described_class.new(regexp)
      strings.map { |string| [js.source, js.flags, string, regexp.match?(string), regexp.inspect] }
    end
    node = E2eRbSpec.node_matches(rows.map { |row| row.first(3) })
    node.zip(rows).each do |js, (source, flags, string, ruby, inspect)|
      expect(js).to eq(ruby), "#{inspect} on #{string.inspect}: Ruby #{ruby}, JS /#{source}/#{flags} #{js}"
    end
  end
end
