require "rails_helper"

RSpec.describe SignupCodesHelper, type: :helper do
  it "names each status in French" do
    user = create(:user, first_name: "Thoren", last_name: "Roy")

    expect(helper.signup_code_status(create(:signup_code))).to include("Actif")
    expect(helper.signup_code_status(create(:signup_code, status: :used, used_by: user))).to include("Utilisé par Thoren Roy")
    expect(helper.signup_code_status(create(:signup_code, status: :expired))).to include("Expiré")
    expect(helper.signup_code_status(create(:signup_code, :expired))).to include("Expiré")
    expect(helper.signup_code_status(create(:signup_code, :deactivated))).to include("Désactivé")
  end
end
