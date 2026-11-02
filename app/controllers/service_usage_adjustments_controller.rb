class ServiceUsageAdjustmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service
  before_action :set_adjustment, only: [:edit, :update, :destroy]

  def create
    adj = @service.service_usage_adjustments.new
    authorize adj
    adj.assign_attributes(permitted_attributes(adj))

    if selectable_employee?(adj) && adj.save
      redirect_to fliip_service_path(@service), notice: "Adjustment added."
    else
      redirect_to fliip_service_path(@service), alert: adj.errors.full_messages.to_sentence
    end
  end

  def edit
    authorize @adjustment
  end

  def update
    authorize @adjustment
    @adjustment.assign_attributes(permitted_attributes(@adjustment))

    if selectable_employee?(@adjustment) && @adjustment.save
      redirect_to fliip_service_path(@service), notice: "Adjustment updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @adjustment
    @adjustment.destroy
    redirect_to fliip_service_path(@service), notice: "Adjustment deleted."
  end

  private

  def set_service
    @service = FliipService.find(params[:fliip_service_id])
  end

  def set_adjustment
    @adjustment = @service.service_usage_adjustments.find(params[:id])
  end

  # Keeps this controller's existing redirect and message.
  def user_not_authorized
    redirect_to fliip_service_path(@service), alert: "Not authorized."
  end

  # The employee must come from User.selectable, so never the super admin.
  # Only checked when it changes, so older adjustments stay editable.
  def selectable_employee?(adjustment)
    return true unless adjustment.user_id_changed?
    return true if User.selectable.exists?(id: adjustment.user_id)

    adjustment.errors.add(:user_id, "n’est pas un·e employé·e valide")
    false
  end
end
