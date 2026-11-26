# Adjustments on the Service page's Ajustements tab (admins write, managers
# read). Each one holds one change (docs/adr/0002). The tab answers with Turbo
# Streams: the list, the service's top card and the tab count are drawn again
# after every change. Plain HTML requests get a redirect to the tab.
class ServiceUsageAdjustmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service
  before_action :set_adjustment, only: [ :show, :edit, :update, :destroy ]
  before_action :load_staff, only: [ :create, :edit, :update ]

  # The adjustment's card, in its frame (« Annuler » in the edit card).
  def show
    authorize @adjustment
    render partial: "service_usage_adjustments/card", locals: { service: @service, adjustment: @adjustment }
  end

  def create
    @adjustment = ServiceUsageAdjustment.new(fliip_service_id: @service.id, created_by: current_user)
    authorize @adjustment
    @adjustment.assign_attributes(permitted_attributes(@adjustment))
    saved = selectable_employee?(@adjustment) && @adjustment.save

    respond_to do |format|
      format.turbo_stream do
        if saved
          render turbo_stream: changed_streams + [ replaced_new_form(new_adjustment) ]
        else
          render turbo_stream: replaced_new_form(@adjustment), status: :unprocessable_content
        end
      end
      format.html { redirect_to_tab(saved ? { notice: "Ajustement ajouté." } : { alert: @adjustment.errors.full_messages.to_sentence }) }
    end
  end

  def edit
    authorize @adjustment
    render partial: "service_usage_adjustments/edit_card", locals: { service: @service, adjustment: @adjustment }
  end

  def update
    authorize @adjustment
    @adjustment.assign_attributes(permitted_attributes(@adjustment))
    saved = selectable_employee?(@adjustment) && @adjustment.save

    respond_to do |format|
      format.turbo_stream do
        if saved
          render turbo_stream: changed_streams
        else
          render turbo_stream: turbo_stream.replace(helpers.dom_id(@adjustment), partial: "service_usage_adjustments/edit_card",
                                                                                 locals: { service: @service, adjustment: @adjustment }),
                 status: :unprocessable_content
        end
      end
      format.html { redirect_to_tab(saved ? { notice: "Ajustement modifié." } : { alert: @adjustment.errors.full_messages.to_sentence }) }
    end
  end

  def destroy
    authorize @adjustment
    @adjustment.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: changed_streams }
      format.html { redirect_to_tab(notice: "Ajustement supprimé.") }
    end
  end

  private

  def set_service
    @service = FliipService.find(params[:fliip_service_id])
  end

  def set_adjustment
    @adjustment = @service.service_usage_adjustments.find(params[:id])
  end

  def load_staff
    @staff = User.selectable.order(:first_name, :last_name).to_a
  end

  def new_adjustment
    ServiceUsageAdjustment.new(fliip_service_id: @service.id, user: current_user)
  end

  # After a change: the tab's list, the service's top card (its counts and
  # bars) and the tab count, from a fresh copy of the service.
  def changed_streams
    service = FliipService.includes(:fliip_user, :service_definition, :service_usage_adjustments).find(@service.id)
    adjustments = service.service_usage_adjustments.sort_by(&:created_at).reverse
    ActiveRecord::Associations::Preloader.new(records: adjustments, associations: %i[user created_by]).call

    [
      turbo_stream.replace(helpers.dom_id(service, :summary), partial: "fliip_services/summary", locals: { service: service }),
      turbo_stream.replace(helpers.dom_id(service, :adjustment_list), partial: "service_usage_adjustments/list",
                                                                      locals: { service: service, adjustments: adjustments }),
      turbo_stream.update(helpers.dom_id(service, :adjustments_count), adjustments.size.to_s)
    ]
  end

  def replaced_new_form(adjustment)
    turbo_stream.replace(helpers.dom_id(@service, :new_adjustment), partial: "service_usage_adjustments/new_form",
                                                                     locals: { service: @service, adjustment: adjustment, staff: @staff })
  end

  def redirect_to_tab(flash)
    redirect_to fliip_service_path(@service, tab: "adjustments"), flash
  end

  # Keeps this controller's existing redirect and message.
  def user_not_authorized
    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.html { redirect_to fliip_service_path(@service), alert: "Non autorisé·e." }
    end
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
