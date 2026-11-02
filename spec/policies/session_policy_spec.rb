require "rails_helper"

RSpec.describe SessionPolicy, type: :policy do
  let(:owner)     { create(:user) }
  let(:session_record) { create(:session, user: owner) }
  let(:confirmed) { create(:session, user: owner).tap { |s| s.update_columns(confirmed: true) } }

  # Routes open to every signed-in user.
  let(:open_actions) { %i[create new row services_table service_select preview_type refresh_clients] }

  it "lets an owner edit their own session until it is confirmed" do
    expect(described_class.new(owner, session_record)).to permit_only_actions(*open_actions, :edit, :update, :destroy)
    expect(described_class.new(owner, confirmed)).to permit_only_actions(*open_actions)
  end

  it "keeps employees and managers out of other people's sessions" do
    expect(described_class.new(create(:user), session_record)).to permit_only_actions(*open_actions)
    expect(described_class.new(create(:user, :manager), session_record)).to permit_only_actions(*open_actions)
  end

  %i[admin super_admin].each do |role|
    it "lets #{role == :admin ? 'an admin' : 'the super admin'} edit any session and change its trainer" do
      everything = [*open_actions, :edit, :update, :destroy, :change_owner]

      expect(described_class.new(user_for(role), confirmed)).to permit_only_actions(*everything)
    end
  end

  it "denies everything to a guest" do
    expect(described_class.new(nil, session_record)).to forbid_all_actions
  end

  describe "#permitted_attributes" do
    it "allows user_id only for admins and the super admin" do
      base = %i[fliip_user_id fliip_service_id present note]

      expect(described_class.new(owner, Session)).to permit_attributes(*base)
      expect(described_class.new(owner, Session)).to forbid_attribute(:user_id)
      expect(described_class.new(create(:user, :manager), Session)).to forbid_attribute(:user_id)
      expect(described_class.new(create(:user, :admin), Session)).to permit_attributes(*base, :user_id)
      expect(described_class.new(create(:user, :super_admin), Session)).to permit_attribute(:user_id)
    end
  end
end
