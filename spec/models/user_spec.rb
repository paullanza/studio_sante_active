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

  describe "other required fields" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:last_name).with_message("ne peut pas être vide") }
    it { is_expected.to validate_presence_of(:address).with_message("ne peut pas être vide") }
  end

  describe "scopes" do
    let!(:employee)    { create(:user) }
    let!(:former)      { create(:user, :inactive) }
    let!(:super_admin) { create(:user, :super_admin) }

    it "splits active from inactive users" do
      expect(described_class.active).to contain_exactly(employee, super_admin)
      expect(described_class.inactive).to contain_exactly(former)
    end

    it ".selectable keeps active users other than the super admin" do
      expect(described_class.selectable).to contain_exactly(employee)
    end
  end

  describe "#translated_role" do
    it "uses the French labels, with admin for both admin roles" do
      expect(build(:user).translated_role).to eq("Employé·e")
      expect(build(:user, :manager).translated_role).to eq("Gestionnaire")
      expect(build(:user, :admin).translated_role).to eq("Admin")
      expect(build(:user, :super_admin).translated_role).to eq("Admin")
    end
  end

  describe "#full_name" do
    it "joins first and last name" do
      expect(build(:user, first_name: "Alex", last_name: "Côté").full_name).to eq("Alex Côté")
    end
  end

  describe "#inactive_message" do
    it "uses Devise's inactive message for deactivated users" do
      expect(build(:user, :inactive).inactive_message).to eq(:inactive)
    end
  end
end
