# app/controllers/manager_controller.rb
class ManagerController < ApplicationController
  include Pagy::Backend
  before_action :authenticate_user!
  before_action :require_manager_only!

  def dashboard
# Staff list (order by role then name)
    @users = User.where.not(role: :super_admin).order(role: :desc, last_name: :asc, first_name: :asc)

    # Per-user unconfirmed session counts (include nil as unconfirmed)
    @unconfirmed_counts = Session
      .where(confirmed: [false, nil])
      .group(:user_id)
      .count

    # Distinct services touched per user (sessions or adjustments)
    # (kept simple & readable; can optimize with a SQL UNION later if needed)
    sessions_pairs = Session.distinct.pluck(:user_id, :fliip_service_id)
    adjust_pairs   = ServiceUsageAdjustment.distinct.pluck(:user_id, :fliip_service_id)

    tmp = Hash.new { |h, k| h[k] = [] }
    sessions_pairs.each { |uid, sid| tmp[uid] << sid }
    adjust_pairs.each { |uid, sid| tmp[uid] << sid }

    @services_touched_counts = tmp.transform_values { |arr| arr.uniq.size }

    # Signup codes (small slice to keep dashboard light)
    @signup_codes = SignupCode.order(created_at: :desc).limit(20)

    # Services ending soon (next 30 days) and ended recently (last 30 days)
    today = Date.current
    @services_ending_soon = FliipService
      .active
      .where(expire_date: today..(today + 30.days))
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(:expire_date)

    @services_ended_recent = FliipService
      .where(expire_date: (today - 30.days)..(today - 1.day))
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(expire_date: :desc)
    # Anything admin-specific is omitted (no unconfirmed summary here)
  end

  def services
    @q = FliipService.order(updated_at: :desc).includes(:fliip_user)
    @pagy, @services = pagy(@q)
  end

  def service_show
    @service = FliipService.includes(:fliip_user).find(params[:id])
    # Show sessions table, etc. No “upload adjustments” entry point here.
    @sessions = @service.sessions.includes(:fliip_user, :created_by).order(date: :desc, time: :desc)
  end

  def create_signup_code
    SignupCode.create!
    redirect_to manager_dashboard_path, notice: "Signup code generated."
  end

  private

  def require_manager_only!
    # Managers only. Admins/SuperAdmins should use the admin dashboard only; employees → profile.
    redirect_to(admin_dashboard_path, alert: "Admins must use the Admin dashboard") and return if current_user.admin? || current_user.super_admin?
    redirect_to(user_path(current_user), alert: "Not authorized") unless current_user.manager?
  end
end
