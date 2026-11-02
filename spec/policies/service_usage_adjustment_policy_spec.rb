require "rails_helper"

RSpec.describe ServiceUsageAdjustmentPolicy, type: :policy do
  let(:adjustment) { create(:service_usage_adjustment) }

  it "hides adjustments from employees" do
    expect(described_class.new(user_for(:employee), adjustment)).to forbid_all_actions
  end

  it "shows managers the tab read-only" do
    expect(described_class.new(user_for(:manager), adjustment)).to permit_only_actions(:index)
  end

  %i[admin super_admin].each do |role|
    it "lets #{role == :admin ? 'an admin' : 'the super admin'} add, edit and delete" do
      expect(described_class.new(user_for(role), adjustment))
        .to permit_only_actions(:index, :new, :create, :edit, :update, :destroy)
    end
  end

  it "permits the deltas and the chosen employee" do
    expect(described_class.new(user_for(:admin), adjustment))
      .to permit_attributes(:paid_used_delta, :free_used_delta, :bonus_sessions, :user_id)
  end
end
