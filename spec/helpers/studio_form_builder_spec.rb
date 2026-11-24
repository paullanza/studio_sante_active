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

    it "puts the label and input in the tile and field_class on the wrapper" do
      html = form_for_user { |f| f.field(:email, label: "Courriel", hint: "Aide", field_class: "form-grid__wide") }

      expect(html.at_css(".field.form-grid__wide > .field__box > label.field__label")).to be_present
      expect(html.at_css(".field__box > input#user_email")["class"]).to eq("field__input")
      expect(html.at_css(".field > .field__hint")).to be_present
    end

    it "refuses an unknown field type" do
      expect { form_for_user { |f| f.field(:email, label: "Courriel", as: :colour) } }
        .to raise_error(ArgumentError, /colour/)
    end
  end

  describe "#code" do
    it "renders one unnamed cell per character and the hidden input that submits" do
      user.signup_code_token = "K7QM"
      html = form_for_user { |f| f.code(:signup_code_token, label: "Code", length: 8, autofocus: true) }
      cells = html.css(".code__cell")

      expect(html.at_css(".field[data-controller=code-input] label#user_signup_code_token_label[for=user_signup_code_token]").text).to eq("Code")
      expect(html.at_css(".code[role=group]")["aria-labelledby"]).to eq("user_signup_code_token_label")
      expect(cells.size).to eq(8)
      expect(cells.map { |c| c["name"] }.uniq).to eq([ nil ])
      expect(cells.map { |c| c["value"].to_s }).to eq(%w[K 7 Q M] + [ "" ] * 4)
      expect(cells.first["id"]).to eq("user_signup_code_token")
      expect(cells.first["autofocus"]).to eq("autofocus")
      expect(cells[1]["autofocus"]).to be_nil
      expect(html.at_css("input[type=hidden][name='user[signup_code_token]']")["value"]).to eq("K7QM")
    end

    it "shows the error and marks the cells invalid" do
      user.errors.add(:signup_code_token, "a expiré")
      html = form_for_user { |f| f.code(:signup_code_token, label: "Code", length: 8) }

      expect(html.at_css(".field")["class"].split).to include("field--invalid")
      expect(html.css(".code__cell").map { |c| c["aria-invalid"] }.uniq).to eq([ "true" ])
      expect(html.at_css(".code")["aria-describedby"]).to eq("user_signup_code_token_error")
      expect(html.at_css("#user_signup_code_token_error").text).to eq("a expiré")
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

    it "checks a boolean's option when the values are 1 and 0" do
      user.active = false
      html = form_for_user { |f| f.segmented(:active, [ [ "Oui", "1" ], [ "Non", "0" ] ], label: "Actif") }

      expect(html.at_css("input[type=radio][value='0']")["checked"]).to eq("checked")
      expect(html.at_css("input[type=radio][value='1']")["checked"]).to be_nil
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

    it "adds the arrow to forward actions only" do
      primary = form_for_user { |f| f.submit("Enregistrer") }.at_css("button")
      ghost = form_for_user { |f| f.submit("Annuler", variant: :ghost) }.at_css("button")

      expect(primary.at_css(".btn__arrow svg")).to be_present
      expect(ghost.at_css(".btn__arrow")).to be_nil
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

    it "adds the full messages of attributes named in also" do
      user.errors.add(:first_name, "ne peut pas être vide")
      html = form_for_user { |f| f.base_errors(also: [ :first_name ]) }

      expect(html.at_css(".flash--alert li").text).to eq("Prénom ne peut pas être vide")
    end

    it "renders nothing without base errors" do
      expect(form_for_user(&:base_errors).at_css(".flash")).to be_nil
    end
  end

  describe "#select_field" do
    it "renders a select in a labelled tile with the current value chosen" do
      user.role = "manager"
      html = form_for_user do |f|
        f.select_field(:role, [ [ "Employé·e", "employee" ], [ "Gestionnaire", "manager" ] ], label: "Rôle")
      end
      select = html.at_css(".field .field__box select#user_role")

      expect(html.at_css("label.field__label[for=user_role]").text).to eq("Rôle")
      expect(select["class"]).to eq("field__input")
      expect(select.at_css("option[selected]").text).to eq("Gestionnaire")
    end

    it "shows the attribute's error" do
      user.errors.add(:role, "est invalide")
      html = form_for_user { |f| f.select_field(:role, [ [ "Employé·e", "employee" ] ], label: "Rôle") }

      expect(html.at_css(".field")["class"].split).to include("field--invalid")
      expect(html.at_css("select")["aria-invalid"]).to eq("true")
      expect(html.at_css(".field__error").text).to eq("est invalide")
    end
  end
end
