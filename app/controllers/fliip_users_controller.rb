class FliipUsersController < ApplicationController
  def index
    @fliip_users = FliipUser.order(:id)
  end

  def show
    @fliip_user = FliipUser.find(params[:id])
  end

  def refresh
    remote_id = params[:remote_id]
    FliipApi::UserSync::UserUpdater.call(remote_id.to_i)
    redirect_to fliip_user_path(FliipUser.find_by(remote_id: remote_id)), notice: "User data refreshed."
  end
end
