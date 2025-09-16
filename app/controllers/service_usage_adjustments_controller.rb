class ServiceUsageAdjustmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service
  before_action :set_adjustment, only: [:edit, :update, :destroy]
  before_action :ensure_admin!, only: [:edit, :update, :destroy] # edit/update/destroy admin only

  def create
    adj = @service.service_usage_adjustments.new(adjustment_params)
    # Non-admins cannot set user_id; force to current_user
    adj.user_id = current_user.id unless current_user.admin? || current_user.super_admin?

    if adj.save
      redirect_to fliip_service_path(@service), notice: "Adjustment added."
    else
      redirect_to fliip_service_path(@service), alert: adj.errors.full_messages.to_sentence
    end
  end

  def edit
  end

  def update
    attrs = adjustment_params
    if @adjustment.update(attrs)
      redirect_to fliip_service_path(@service), notice: "Adjustment updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
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

  def ensure_admin!
    unless current_user.admin? || current_user.super_admin?
      redirect_to fliip_service_path(@service), alert: "Not authorized."
    end
  end

  def adjustment_params
    permitted = [:paid_used_delta, :free_used_delta, :bonus_sessions]
    permitted << :user_id if current_user.admin? || current_user.super_admin?
    params.require(:service_usage_adjustment).permit(*permitted)
  end
end
