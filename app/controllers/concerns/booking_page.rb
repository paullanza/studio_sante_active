# Everything the « Saisir » page (bookings/new) needs. BookingsController#new
# renders it, and SessionsController#create and ConsultationsController#create
# re-render it when a save fails, so the three stay in step.
module BookingPage
  extend ActiveSupport::Concern

  BOOKING_TABS = %w[session consultation].freeze

  private

  # Keeps an @session or @consultation the caller already built (a failed
  # save), so its values and errors show again. `trainer_id` is the admin's
  # trainer choice; the side list shows that trainer's latest séances.
  def prepare_booking_page(client_id:, tab:, service_id: nil, trainer_id: nil)
    @tab = BOOKING_TABS.include?(tab) ? tab : "session"
    chosen_trainer = chosen_booking_trainer(trainer_id)
    @client = client_id.present? ? FliipUser.find_by(id: client_id) : nil
    @services = @client ? @client.fliip_services.includes(:service_definition).order(Arel.sql("expire_date DESC NULLS LAST")).to_a : []
    @bookable = @services.reject(&:booking_blocked?)
    @session ||= Session.new(fliip_user: @client, fliip_service_id: chosen_service_id(service_id), duration: 1.0, present: true,
                             user: chosen_trainer)
    @trainer = @session.user || current_user
    @recent_sessions = Session.where(user: @trainer).with_associations.order_by_occurred_at_desc.limit(10)
    @consultation ||= Consultation.new(present: true)
    load_booking_staff
  end

  # The requested service when it can be booked, else the only bookable one.
  def chosen_service_id(requested_id)
    requested = @bookable.find { |service| service.id.to_s == requested_id.to_s }
    return requested.id if requested

    @bookable.size == 1 ? @bookable.first.id : nil
  end

  # The trainer an admin picked (selectable staff only); nil otherwise.
  def chosen_booking_trainer(trainer_id)
    return nil if trainer_id.blank? || !policy(Session).change_owner?

    User.selectable.find_by(id: trainer_id)
  end

  # Admins pick the trainer. The super admin is not selectable, so must pick
  # an employee.
  def load_booking_staff
    @staff = policy(Session).change_owner? ? User.selectable.order(:first_name, :last_name).to_a : []
    @owner_required = @staff.any? && @staff.none? { |u| u.id == current_user.id }
  end
end
