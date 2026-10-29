require "rails_helper"

RSpec.describe "Factories" do
  it "are all valid" do
    FactoryBot.lint traits: true
  end
end
