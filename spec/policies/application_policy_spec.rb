require "rails_helper"

RSpec.describe ApplicationPolicy, type: :policy do
  %i[employee manager admin super_admin].each do |role|
    it "denies every action to a #{role} by default" do
      expect(described_class.new(user_for(role), :anything)).to forbid_all_actions
    end
  end

  it "denies everything to a guest" do
    expect(described_class.new(nil, :anything)).to forbid_all_actions
  end

  describe "role helpers" do
    {
      employee: { employee?: true, manager_or_above?: false, admin_or_above?: false },
      manager: { manager?: true, manager_or_above?: true, admin_or_above?: false },
      admin: { admin?: true, super_admin?: false, manager_or_above?: true, admin_or_above?: true },
      super_admin: { super_admin?: true, admin?: false, manager_or_above?: true, admin_or_above?: true }
    }.each do |role, expectations|
      it "answer for a #{role}" do
        policy = described_class.new(user_for(role), :anything)

        expectations.each do |helper, expected|
          expect(policy.send(helper)).to eq(expected), helper.to_s
        end
      end
    end

    it "are falsy without a user" do
      policy = described_class.new(nil, :anything)

      expect(policy.send(:admin_or_above?)).to be_falsy
      expect(policy.send(:manager_or_above?)).to be_falsy
    end
  end

  it "requires every Scope to define resolve" do
    expect { described_class::Scope.new(nil, User).resolve }.to raise_error(NoMethodError, /You must define #resolve/)
  end
end
