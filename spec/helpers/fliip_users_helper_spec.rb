require "rails_helper"

RSpec.describe FliipUsersHelper, type: :helper do
  describe "#client_avatar" do
    it "shows the Fliip photo" do
      client = build(:fliip_user, user_image: "https://fliipimages.s3.amazonaws.com/images/user_image/abc.jpg")

      expect(helper.client_avatar(client)).to include('src="https://fliipimages.s3.amazonaws.com/images/user_image/abc.jpg"')
    end

    it "shows the initials instead of Fliip's default image or no image" do
      default = build(:fliip_user, user_firstname: "Ysolde", user_lastname: "Brisebois",
        user_image: "https://fliipimages.s3.amazonaws.com/images/user_image/default.png")

      expect(helper.client_avatar(default)).to include(">YB<").and include("avatar--initials")
      expect(helper.client_avatar(build(:fliip_user, user_image: nil))).to include("avatar--initials")
    end
  end

  describe "#membership_length" do
    let(:today) { Date.new(2026, 11, 22) }

    it "counts years and months" do
      expect(helper.membership_length(Date.new(2021, 4, 26), today: today)).to eq("5 ans 6 mois")
      expect(helper.membership_length(Date.new(2025, 11, 1), today: today)).to eq("1 an")
      expect(helper.membership_length(Date.new(2026, 8, 22), today: today)).to eq("3 mois")
    end

    it "says less than a month for a new member" do
      expect(helper.membership_length(Date.new(2026, 11, 1), today: today)).to eq("Moins d'un mois")
    end

    it "is nil without a date or with a future date" do
      expect(helper.membership_length(nil, today: today)).to be_nil
      expect(helper.membership_length(Date.new(2027, 1, 1), today: today)).to be_nil
    end
  end
end
