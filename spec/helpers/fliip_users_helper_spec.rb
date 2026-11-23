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
end
