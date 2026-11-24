require "rails_helper"

RSpec.describe MyServicesPolicy, type: :policy do
  %i[employee manager admin super_admin].each do |role|
    it "opens Mes services to a #{role}" do
      expect(described_class.new(user_for(role), :my_services)).to permit_only_actions(:index)
    end
  end

  it "denies it to a guest" do
    expect(described_class.new(nil, :my_services)).to forbid_all_actions
  end
end
