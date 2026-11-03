require "rails_helper"

RSpec.describe AdminPolicy, type: :policy do
  %i[admin super_admin].each do |role|
    it "permits every admin action to #{role == :admin ? 'an admin' : 'the super admin'}" do
      expect(described_class.new(user_for(role), :admin)).to permit_actions(
        :dashboard, :services, :service_show, :update_service, :client_services, :import_clients,
        :create_signup_code, :deactivate_signup_code, :unconfirmed_sessions, :confirm_sessions,
        :unconfirmed_consultations, :confirm_consultations, :adjustments_new, :adjustments_preview,
        :adjustments_commit, :jobs
      )
    end
  end

  %i[employee manager].each do |role|
    it "forbids every action to a #{role}" do
      expect(described_class.new(user_for(role), :admin)).to forbid_all_actions
    end
  end
end
