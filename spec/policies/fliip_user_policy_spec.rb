require "rails_helper"

RSpec.describe FliipUserPolicy, type: :policy do
  let(:client) { create(:fliip_user) }

  %i[employee manager admin super_admin].each do |role|
    it "lets a #{role} browse, search and refresh clients" do
      expect(described_class.new(user_for(role), client)).to permit_only_actions(:index, :show, :suggest, :refresh)
    end
  end

  it "denies everything to a guest" do
    expect(described_class.new(nil, client)).to forbid_all_actions
  end
end
