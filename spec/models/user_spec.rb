require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:first_name).with_message("ne peut pas être vide") }
    it { is_expected.to validate_presence_of(:phone).with_message("ne peut pas être vide") }
    it { is_expected.to validate_presence_of(:birthday).with_message("ne peut pas être vide") }
  end

  describe "signup code" do
    it "requires a code" do
      user = build(:user, signup_code_token: nil)
      expect(user).not_to be_valid
      expect(user.errors[:signup_code_token]).to include("ne peut pas être vide")
    end

    it "rejects an unknown code" do
      user = build(:user, signup_code_token: "NOPE1234")
      user.validate
      expect(user.errors[:signup_code_token]).to include("est invalide")
    end

    it "rejects a deactivated code" do
      code = create(:signup_code, :deactivated)
      user = build(:user, signup_code_token: code.code)
      user.validate
      expect(user.errors[:signup_code_token]).to include("a été désactivé")
    end

    it "rejects a used code" do
      code = create(:user).signup_code
      user = build(:user, signup_code_token: code.code)
      user.validate
      expect(user.errors[:signup_code_token]).to include("a déjà été utilisé")
    end

    it "rejects a code past its expiry date" do
      code = create(:signup_code, :expired)
      user = build(:user, signup_code_token: code.code)
      user.validate
      expect(user.errors[:signup_code_token]).to include("a expiré")
    end

    it "marks the code as used by the new user" do
      code = create(:signup_code)
      user = create(:user, signup_code_token: code.code)

      expect(code.reload).to be_used
      expect(code.used_by).to eq(user)
    end
  end

  describe "#active_for_authentication?" do
    it "is false for deactivated users" do
      expect(build(:user, :inactive).active_for_authentication?).to be false
      expect(build(:user).active_for_authentication?).to be true
    end
  end
end
