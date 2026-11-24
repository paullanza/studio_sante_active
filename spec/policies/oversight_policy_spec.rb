require "rails_helper"

RSpec.describe OversightPolicy, type: :policy do
  %i[manager admin super_admin].each do |role|
    it "permits the oversight pages to a#{'n' if role == :admin} #{role}" do
      expect(described_class.new(user_for(role), :oversight)).to permit_only_actions(:echeances, :recent_sessions)
    end
  end

  it "forbids them to an employee" do
    expect(described_class.new(user_for(:employee), :oversight)).to forbid_all_actions
  end
end
