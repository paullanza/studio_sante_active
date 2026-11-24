require "rails_helper"

RSpec.describe "layouts/_studio_nav", type: :view do
  def render_nav_for(user)
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:policy) { |record| Pundit.policy!(user, record) }
    end
    render partial: "layouts/studio_nav"
    Nokogiri::HTML.fragment(rendered)
  end

  def plus_items(html)
    html.css(".nav-more__item").map { |item| item["value"] || item.text.strip }
  end

  it "shows the five tabs" do
    html = render_nav_for(create(:user))

    expect(html.css(".top-nav__inner > .nav-tab, .nav-more > summary").map(&:text).map(&:strip))
      .to eq([ "Dashboard", "Clients", "Saisir", "Mes services", "Plus" ])
  end

  it "gives an employee only their profile and sign out" do
    expect(plus_items(render_nav_for(create(:user)))).to eq([ "Mon profil", "Se déconnecter" ])
  end

  it "adds consultation linking and Échéances for a manager" do
    expect(plus_items(render_nav_for(create(:user, :manager))))
      .to eq([ "Mon profil", "Lier les consultations", "Échéances", "Se déconnecter" ])
  end

  it "adds the admin pages for an admin and the super admin" do
    expected = [ "Mon profil", "Confirmations séances", "Confirmations consultations",
                 "Lier les consultations", "Échéances", "Allocations", "Tâches", "Se déconnecter" ]

    expect(plus_items(render_nav_for(create(:user, :admin)))).to eq(expected)
    expect(plus_items(render_nav_for(create(:user, :super_admin)))).to eq(expected)
  end

  it "signs out with a DELETE form" do
    form = render_nav_for(create(:user)).at_css("form.nav-more__form")

    expect(form.at_css("input[name=_method]")["value"]).to eq("delete")
  end

  it "marks the declared section's tab active" do
    view.content_for(:nav_section, "plus")
    summary = render_nav_for(create(:user)).at_css(".nav-more > summary")

    expect(summary["class"].split).to include("is-active")
  end
end
