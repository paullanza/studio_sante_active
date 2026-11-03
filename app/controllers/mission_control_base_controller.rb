# Base class for Mission Control's controllers (/jobs): signed-in admins and
# above only, through the admin policy.
class MissionControlBaseController < ApplicationController
  before_action :authenticate_user!
  before_action { authorize :admin, :jobs? }
end
