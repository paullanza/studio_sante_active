# One user per role, for policy and request specs. Admin and super admin stay distinct.
module RoleUsers
  def user_for(role)
    role == :employee ? create(:user) : create(:user, role)
  end
end

RSpec.configure do |config|
  config.include RoleUsers, type: :policy
  config.include RoleUsers, type: :request
end
