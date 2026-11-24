# « Saisir »: log a séance (or a consultation) on one page with two tabs.
class BookingsController < ApplicationController
  include BookingPage

  layout "studio"

  before_action :authenticate_user!

  def new
    authorize :booking

    prepare_booking_page(client_id: params[:fliip_user_id], tab: params[:tab], service_id: params[:fliip_service_id])
  end
end
