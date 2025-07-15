class FliipUsersController < ApplicationController
  def index
    @fliip_users = FliipUser.order(:id)
  end

  def show
    @fliip_user = FliipUser.find(params[:id])
  end
end
