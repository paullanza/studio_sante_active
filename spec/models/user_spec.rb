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

  describe "#active_status_change_allowed?" do
    let(:employee)    { create(:user) }
    let(:manager)     { create(:user, :manager) }
    let(:admin)       { create(:user, :admin) }
    let(:super_admin) { create(:user, :super_admin) }

    it "never lets users change their own status" do
      expect(admin.active_status_change_allowed?(admin)).to be false
    end

    it "lets admins and super admins change anyone" do
      expect(manager.active_status_change_allowed?(admin)).to be true
      expect(admin.active_status_change_allowed?(super_admin)).to be true
    end

    it "lets managers change employees only" do
      expect(employee.active_status_change_allowed?(manager)).to be true
      expect(create(:user, :manager).active_status_change_allowed?(manager)).to be false
    end

    it "does not let employees change anyone" do
      expect(create(:user).active_status_change_allowed?(employee)).to be false
    end
  end

  describe "#editable_by?" do
    let(:user) { create(:user) }

    it "allows the user themself and admins" do
      expect(user.editable_by?(user)).to be true
      expect(user.editable_by?(create(:user, :admin))).to be true
      expect(user.editable_by?(create(:user, :super_admin))).to be true
    end

    it "does not allow managers or other employees" do
      expect(user.editable_by?(create(:user, :manager))).to be false
      expect(user.editable_by?(create(:user))).to be false
      expect(user.editable_by?(nil)).to be false
    end
  end
end
