require "rails_helper"

RSpec.describe ConsultationPolicy, type: :policy do
  let(:owner)        { create(:user) }
  let(:consultation) { create(:consultation, user: owner) }
  let(:confirmed)    { create(:consultation, user: owner, confirmed: true) }

  let(:open_actions)        { %i[create new row] }
  let(:association_actions) { %i[association associate service_select associations] }

  it "lets an owner edit until confirmed, but never associate" do
    expect(described_class.new(owner, consultation)).to permit_only_actions(*open_actions, :edit, :update, :destroy)
    expect(described_class.new(owner, confirmed)).to permit_only_actions(*open_actions)
  end

  it "lets managers associate any consultation, confirmed or not, without editing or disassociating it" do
    manager = create(:user, :manager)

    expect(described_class.new(manager, confirmed)).to permit_only_actions(*open_actions, *association_actions)
  end

  %i[admin super_admin].each do |role|
    it "lets #{role == :admin ? 'an admin' : 'the super admin'} do everything, disassociation included" do
      everything = [*open_actions, *association_actions, :edit, :update, :destroy, :disassociate, :change_owner]

      expect(described_class.new(user_for(role), confirmed)).to permit_only_actions(*everything)
    end
  end

  it "denies everything to a guest" do
    expect(described_class.new(nil, consultation)).to forbid_all_actions
  end

  describe "#permitted_attributes" do
    it "allows user_id only for admins and the super admin" do
      base = %i[first_name last_name email phone_number note present]

      expect(described_class.new(owner, Consultation)).to permit_attributes(*base)
      expect(described_class.new(create(:user, :manager), Consultation)).to forbid_attribute(:user_id)
      expect(described_class.new(create(:user, :admin), Consultation)).to permit_attributes(*base, :user_id)
      expect(described_class.new(create(:user, :super_admin), Consultation)).to permit_attribute(:user_id)
    end
  end
end
