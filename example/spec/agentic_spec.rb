# frozen_string_literal: true

# Needs a model: E2E_MODEL + E2E_MODEL_PROVIDER and that provider's settings (.env.example).
# Run with `docker compose run --rm agentic`.
require "e2e_rb/rspec"

RSpec.describe "greeting page, agent-driven", type: :e2e do
  it "the agent gets a greeting" do
    app.open("/")
    agent.act("get the app to greet {name}", params: { name: "Grace" })
    expect(screen.get_by_role("status")).to have_text("hello, Grace!")
    agent.assert("the app greets Grace by name")
  end
end
