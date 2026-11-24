require "rails_helper"

RSpec.describe ServiceDefinitionPolicy, type: :policy do
  let(:definition) { build(:service_definition) }

  %i[admin super_admin].each do |role|
    # edit? follows update? (ApplicationPolicy); there is no edit route.
    it "permits the allocations pages to #{role == :admin ? 'an admin' : 'the super admin'}" do
      expect(described_class.new(user_for(role), definition)).to permit_only_actions(%i[index show edit update])
    end
  end

  %i[employee manager].each do |role|
    it "forbids them to a#{'n' if role == :employee} #{role}" do
      expect(described_class.new(user_for(role), definition)).to forbid_all_actions
    end
  end

  it "permits only the two counts" do
    expect(described_class.new(user_for(:admin), definition).permitted_attributes).to eq(%i[paid_sessions free_sessions])
  end
end
