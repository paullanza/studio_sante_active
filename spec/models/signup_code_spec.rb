require "rails_helper"

RSpec.describe SignupCode, type: :model do
  describe "on create" do
    it "generates an 8-character code without ambiguous characters" do
      code = create(:signup_code)

      expect(code.code).to match(/\A[A-Z2-9]{8}\z/)
      expect(code.code).not_to match(/[0O1IL]/)
    end

    it "sets an expiry date in the future" do
      expect(create(:signup_code).expiry_date).to be_future
    end
  end

  describe "#usable?" do
    it "is true for active, unexpired codes" do
      expect(create(:signup_code)).to be_usable
    end

    it "is false once expired or deactivated" do
      expect(create(:signup_code, :expired)).not_to be_usable
      expect(create(:signup_code, :deactivated)).not_to be_usable
    end
  end

  describe "#safely_deactivate!" do
    it "deactivates a usable code" do
      code = create(:signup_code)
      expect(code.safely_deactivate!).to be_truthy
      expect(code).to be_deactivated
    end

    it "refuses expired codes" do
      expect(create(:signup_code, :expired).safely_deactivate!).to be false
    end
  end

  describe ".expire_old_codes!" do
    it "marks active codes past their expiry as expired" do
      old  = create(:signup_code, :expired)
      good = create(:signup_code)

      described_class.expire_old_codes!

      expect(old.reload).to be_expired
      expect(good.reload).to be_active
    end
  end

  describe "validations" do
    subject { create(:signup_code) }

    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_length_of(:code).is_equal_to(8) }
    it { is_expected.to belong_to(:used_by).class_name("User").optional }
  end

  it "keeps a code given on create" do
    expect(create(:signup_code, code: "ABCDEFGH").code).to eq("ABCDEFGH")
  end

  describe ".usable" do
    it "returns active codes that have not expired" do
      fresh = create(:signup_code)
      create(:signup_code, :expired)
      create(:signup_code, :deactivated)

      expect(described_class.usable).to contain_exactly(fresh)
    end
  end

  describe "#expired_by_time? and #mark_as_expired!" do
    it "expires an active code past its date" do
      code = create(:signup_code, :expired)

      expect(code).to be_expired_by_time
      expect(code.mark_as_expired!).to be true
      expect(code.reload).to be_expired
    end

    it "leaves a code that is still valid" do
      code = create(:signup_code)

      expect(code).not_to be_expired_by_time
      expect(code.mark_as_expired!).to be false
      expect(code.reload).to be_active
    end
  end

  describe "#used!" do
    it "marks the code used by a user" do
      code = create(:signup_code)
      user = create(:user)

      code.used!(by: user)

      expect(code.reload).to be_used
      expect(code.used_by).to eq(user)
    end
  end
end
