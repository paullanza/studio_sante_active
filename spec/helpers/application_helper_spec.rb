require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#owner_options" do
    let(:staff) { create_list(:user, 2) }

    it "adds the current owner when they are not in the staff list" do
      former = create(:user, :inactive)

      expect(helper.owner_options(staff, former)).to eq(staff + [former])
    end

    it "does not duplicate an owner who is already listed" do
      expect(helper.owner_options(staff, staff.first)).to eq(staff)
    end

    it "returns the staff list when there is no owner" do
      expect(helper.owner_options(staff, nil)).to eq(staff)
    end
  end

  describe "#owner_option_label" do
    it "marks inactive users" do
      user = build(:user, :inactive, first_name: "Marie", last_name: "Roy")

      expect(helper.owner_option_label(user)).to eq("Marie Roy (inactif·ve)")
    end

    it "shows active users by name" do
      user = build(:user, first_name: "Alex", last_name: "Côté")

      expect(helper.owner_option_label(user)).to eq("Alex Côté")
    end
  end
end
