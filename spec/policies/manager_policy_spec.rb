require "rails_helper"

RSpec.describe ManagerPolicy, type: :policy do
  it "permits the manager pages to managers" do
    expect(described_class.new(user_for(:manager), :manager)).to permit_only_actions(:dashboard, :create_signup_code)
  end

  %i[employee admin super_admin].each do |role|
    it "forbids them to a#{'n' if role != :super_admin} #{role}" do
      expect(described_class.new(user_for(role), :manager)).to forbid_all_actions
    end
  end
end
