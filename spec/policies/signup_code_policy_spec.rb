require "rails_helper"

RSpec.describe SignupCodePolicy, type: :policy do
  let(:usable) { create(:signup_code) }
  let(:used)   { create(:signup_code, status: :used) }

  %i[manager admin super_admin].each do |role|
    it "lets a #{role} list, create and deactivate a usable code" do
      expect(described_class.new(user_for(role), usable)).to permit_only_actions(:index, :new, :create, :deactivate)
    end

    it "doesn't let a #{role} deactivate a code that can't be used any more" do
      expect(described_class.new(user_for(role), used)).to permit_only_actions(:index, :new, :create)
      expect(described_class.new(user_for(role), create(:signup_code, :expired))).to forbid_action(:deactivate)
    end
  end

  it "forbids everything to an employee and a guest" do
    expect(described_class.new(user_for(:employee), usable)).to forbid_all_actions
    expect(described_class.new(nil, usable)).to forbid_all_actions
  end
end
