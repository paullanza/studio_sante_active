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
end
