require "rails_helper"

# The rebuilt pages' layout (layouts/studio): who is signed in.
RSpec.describe "Studio nav", type: :request do
  def signed_in_name
    Nokogiri::HTML(response.body).at_css(".brand-bar .signed-in-as__name")&.text
  end

  it "shows the signed-in staff member's name" do
    sign_in create(:user, first_name: "Ysolde", last_name: "Brisebois")

    get my_services_path

    expect(signed_in_name).to eq("Ysolde Brisebois")
  end

  it "shows no name when signed out" do
    get new_user_session_path

    expect(signed_in_name).to be_nil
  end
end
