require "rails_helper"

RSpec.describe LayoutHelper, type: :helper do
  describe "#home_path" do
    it "goes to sign in when signed out" do
      without_partial_double_verification { allow(helper).to receive(:user_signed_in?).and_return(false) }

      expect(helper.home_path).to eq(new_user_session_path)
    end

    it "goes to the user's landing page when signed in" do
      admin = create(:user, :admin)
      without_partial_double_verification { allow(helper).to receive_messages(user_signed_in?: true, current_user: admin) }

      expect(helper.home_path).to eq(admin_dashboard_path)
    end
  end

  describe "#back_link_to" do
    it "renders a back link with a decorative arrow" do
      html = Nokogiri::HTML.fragment(helper.back_link_to("Clients", "/fliip_users"))
      link = html.at_css("a.back-link")

      expect(link["href"]).to eq("/fliip_users")
      expect(link.text.strip).to eq("Clients")
      expect(link.at_css("svg")["aria-hidden"]).to eq("true")
    end
  end

  describe "#nav_tab_to" do
    it "marks the tab of the page's section as active" do
      helper.content_for(:nav_section, "clients")
      link = Nokogiri::HTML.fragment(helper.nav_tab_to("Clients", "/fliip_users", :clients)).at_css("a")

      expect(link["class"].split).to include("nav-tab", "is-active")
      expect(link["aria-current"]).to eq("page")
      expect(link.at_css(".nav-tab__label").text).to eq("Clients")
    end

    it "leaves other tabs inactive" do
      helper.content_for(:nav_section, "saisir")
      link = Nokogiri::HTML.fragment(helper.nav_tab_to("Clients", "/fliip_users", :clients)).at_css("a")

      expect(link["class"].split).not_to include("is-active")
      expect(link["aria-current"]).to be_nil
    end

    it "leaves every tab inactive when the page declares no section" do
      link = Nokogiri::HTML.fragment(helper.nav_tab_to("Clients", "/fliip_users", :clients)).at_css("a")

      expect(link["class"].split).not_to include("is-active")
    end
  end
end
