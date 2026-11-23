require "rails_helper"

RSpec.describe StudioFormBuilder, type: :helper do
  let(:user) { build(:user) }

  def form_for_user(&block)
    html = helper.form_with(model: user, url: "/test", scope: :user, builder: described_class, &block)
    Nokogiri::HTML.fragment(html)
  end

  describe "#field" do
    it "renders the label, input and hint wired together" do
      html = form_for_user { |f| f.field(:email, label: "Courriel", as: :email, hint: "Votre courriel", autocomplete: "email") }
      input = html.at_css("input#user_email")

      expect(html.at_css(".field label.field__label[for=user_email]").text).to eq("Courriel")
      expect(input["type"]).to eq("email")
      expect(input["class"]).to eq("field__input")
      expect(input["autocomplete"]).to eq("email")
      expect(input["aria-describedby"]).to eq("user_email_hint")
      expect(input["aria-invalid"]).to be_nil
      expect(html.at_css("#user_email_hint").text).to eq("Votre courriel")
      expect(html.at_css(".field--invalid")).to be_nil
    end

    it "shows the attribute's first error and marks the input invalid" do
      user.errors.add(:email, "est invalide")
      user.errors.add(:email, "est déjà utilisé·e")
      html = form_for_user { |f| f.field(:email, label: "Courriel", as: :email, hint: "Votre courriel") }
      input = html.at_css("input#user_email")

      expect(html.at_css(".field")["class"].split).to include("field--invalid")
      expect(input["aria-invalid"]).to eq("true")
      expect(input["aria-describedby"]).to eq("user_email_hint user_email_error")
      expect(html.css(".field__error").map(&:text)).to eq([ "est invalide" ])
    end

    it "renders a textarea and the label's aside" do
      html = form_for_user do |f|
        f.field(:address, label: "Adresse", as: :textarea, label_aside: helper.link_to("Aide", "/aide"))
      end

      expect(html.at_css("textarea#user_address.field__input")).to be_present
      expect(html.at_css(".field__label-row a[href='/aide']").text).to eq("Aide")
    end

    it "refuses an unknown field type" do
      expect { form_for_user { |f| f.field(:email, label: "Courriel", as: :colour) } }
        .to raise_error(ArgumentError, /colour/)
    end
  end

  describe "#check" do
    it "wraps the checkbox in its label" do
      html = form_for_user { |f| f.check(:remember_me, label: "Se souvenir de moi") }

      expect(html.at_css("label.checkbox input[type=checkbox].checkbox__input")).to be_present
      expect(html.at_css("label.checkbox .checkbox__label").text).to eq("Se souvenir de moi")
    end
  end

  describe "#segmented" do
    it "checks the option matching the current value" do
      user.role = "manager"
      html = form_for_user do |f|
        f.segmented(:role, [ [ "Employé·e", "employee" ], [ "Gestionnaire", "manager" ] ], label: "Rôle")
      end

      expect(html.at_css("fieldset.field legend.field__label").text).to eq("Rôle")
      expect(html.css(".segmented__text").map(&:text)).to eq([ "Employé·e", "Gestionnaire" ])
      expect(html.at_css("input[type=radio][value=manager]")["checked"]).to eq("checked")
      expect(html.at_css("input[type=radio][value=employee]")["checked"]).to be_nil
    end

    it "shows an error under the options" do
      user.errors.add(:role, "doit être indiqué")
      html = form_for_user { |f| f.segmented(:role, [ [ "Employé·e", "employee" ] ], label: "Rôle") }

      expect(html.at_css("fieldset")["class"].split).to include("field--invalid")
      expect(html.at_css("fieldset")["aria-describedby"]).to eq("user_role_error")
      expect(html.at_css("#user_role_error").text).to eq("doit être indiqué")
    end
  end

  describe "#submit" do
    it "renders a gold submit button by default" do
      button = form_for_user { |f| f.submit("Se connecter", block: true) }.at_css("button")

      expect(button["type"]).to eq("submit")
      expect(button["name"]).to be_nil
      expect(button["class"]).to eq("btn btn--primary btn--block")
      expect(button.text).to eq("Se connecter")
    end

    it "renders other variants" do
      button = form_for_user { |f| f.submit("Annuler", variant: :ghost) }.at_css("button")

      expect(button["class"]).to eq("btn btn--ghost")
    end

    it "refuses an unknown variant" do
      expect { form_for_user { |f| f.submit("X", variant: :gold) } }.to raise_error(ArgumentError, /gold/)
    end
  end

  describe "#base_errors" do
    it "lists the errors on :base as an alert" do
      user.errors.add(:base, "Indiquez un téléphone ou un courriel.")
      html = form_for_user(&:base_errors)

      expect(html.at_css(".flash--alert[role=alert] li").text).to eq("Indiquez un téléphone ou un courriel.")
    end

    it "renders nothing without base errors" do
      expect(form_for_user(&:base_errors).at_css(".flash")).to be_nil
    end
  end
end
