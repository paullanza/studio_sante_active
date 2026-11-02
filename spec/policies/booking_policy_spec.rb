require "rails_helper"

RSpec.describe BookingPolicy, type: :policy do
  %i[employee manager admin super_admin].each do |role|
    it "opens the booking page to a #{role}" do
      expect(described_class.new(user_for(role), :booking)).to permit_only_actions(:new)
    end
  end

  it "denies it to a guest" do
    expect(described_class.new(nil, :booking)).to forbid_all_actions
  end
end
