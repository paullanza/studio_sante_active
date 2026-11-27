require "rails_helper"

RSpec.describe "Codes d'inscription", type: :request do
  let(:code) { create(:signup_code) }

  it "is closed to employees" do
    sign_in create(:user)

    get signup_codes_path
    expect(response).to redirect_to(authenticated_root_path)
    expect { post signup_codes_path }.not_to change(SignupCode, :count)
    patch deactivate_signup_code_path(code)
    expect(code.reload).to be_active
  end

  %i[manager admin super_admin].each do |role|
    context "as #{role}" do
      before { sign_in create(:user, role) }

      it "lists the codes" do
        code
        get signup_codes_path

        expect(response).to have_http_status(:ok)
      end

      it "creates a code and shows it on top" do
        expect { post signup_codes_path }.to change(SignupCode, :count).by(1)

        created = SignupCode.last
        expect(response).to redirect_to(signup_codes_path(highlight: created.id))
        expect(flash[:notice]).to eq("Code créé.")
        follow_redirect!
        # The highlighted code is only visible in the markup.
        expect(Nokogiri::HTML(response.body).at_css(".signup-code--large").text).to eq(created.code)
      end

      it "deactivates a usable code" do
        patch deactivate_signup_code_path(code)

        expect(code.reload).to be_deactivated
        expect(response).to redirect_to(signup_codes_path)
        expect(flash[:notice]).to eq("Code désactivé.")
      end
    end
  end

  it "refuses to deactivate a used code with its own message" do
    used = create(:signup_code, status: :used)
    sign_in create(:user, :manager)

    patch deactivate_signup_code_path(used)

    expect(used.reload).to be_used
    expect(response).to redirect_to(signup_codes_path)
    expect(flash[:alert]).to eq("Ce code ne peut plus être désactivé.")
  end

  it "marks an active code past its date as expired when the page opens" do
    stale = create(:signup_code, :expired)
    sign_in create(:user, :manager)

    get signup_codes_path

    expect(stale.reload).to be_expired
  end
end
