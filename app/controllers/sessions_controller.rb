class SessionsController < ApplicationController
  before_action :authenticate_user!

  def new
    @session = Session.new
    load_fliip_users_and_services
  end

  def create
    @session = Session.new(session_params)
    @session.user = current_user
    @session.confirmed = false
    @session.present = params[:session][:present] == "1"

    if @session.save
      redirect_to root_path, notice: "Session created successfully."
    else
      load_fliip_users_and_services
      flash.now[:alert] = "There was a problem creating the session."
      render :new
    end
  end

  private

  def load_fliip_users_and_services
    service_user_ids = FliipService.distinct.pluck(:fliip_user_id)

    @fliip_users = FliipUser
      .where(id: service_user_ids)
      .sort_by do |u|
        I18n.transliterate("#{u.user_lastname.strip} #{u.user_firstname.strip}").downcase
      end

    @fliip_services = FliipService.order(:service_name)
  end

  def session_params
    params.require(:session).permit(
      :fliip_user_id,
      :fliip_service_id,
      :date,
      :time,
      :present,
      :note,
      :duration
    )
  end
end
