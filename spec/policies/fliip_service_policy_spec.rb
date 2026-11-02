require "rails_helper"

RSpec.describe FliipServicePolicy, type: :policy do
  let(:service) { create(:fliip_service) }

  %i[employee manager admin super_admin].each do |role|
    it "lets a #{role} view a service" do
      expect(described_class.new(user_for(role), service)).to permit_only_actions(:show)
    end
  end

  it "denies everything to a guest" do
    expect(described_class.new(nil, service)).to forbid_all_actions
  end
end
