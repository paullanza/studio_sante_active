class SessionsController < ApplicationController
  before_action :authenticate_user!

  def new
    @session = Session.new
    service_user_ids = FliipService.distinct.pluck(:fliip_user_id)

    @fliip_users = FliipUser
      .where(id: service_user_ids)
      .sort_by { |u| I18n.transliterate("#{u.user_lastname.strip} #{u.user_firstname.strip}").downcase }

    @fliip_services = FliipService.order(:service_name)
  end

  def create
    @session = Session.new(session_params)
    @session.user = current_user
    @session.confirmed = false

    if @session.save
      redirect_to root_path, notice: "Session created successfully."
    else
      @fliip_users = FliipUser.order(:first_name, :last_name)
      flash.now[:alert] = "There was a problem creating the session."
      render :new
    end
  end

  private

  def session_params
    params.require(:session).permit(
      :fliip_user_id,
      :fliip_service_id,
      :date,
      :time,
      :present,
      :note
    )
  end
end
