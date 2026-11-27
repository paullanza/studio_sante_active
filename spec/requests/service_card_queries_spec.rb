require "rails_helper"

# Lists of service cards count séances and adjustments with
# FliipService.preload_usage: the number of queries must not grow with the
# number of cards.
RSpec.describe "Service card queries", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:client)     { create(:fliip_user) }
  let(:definition) { create(:service_definition) }

  # A service with a séance by the admin, an absence and two adjustments.
  def add_services(count, **attributes)
    create_list(:fliip_service, count, fliip_user: client, service_definition: definition, **attributes).each do |service|
      create(:session, fliip_service: service, user: admin, occurred_at: 2.days.ago)
      create(:session, fliip_service: service, user: admin, present: false, occurred_at: 3.days.ago)
      create(:service_usage_adjustment, :paid_used, fliip_service: service, user: admin)
      create(:service_usage_adjustment, :free_bonus, fliip_service: service, user: admin)
    end
  end

  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    expect(response).to have_http_status(:ok)
    count
  end

  # Queries with 2 cards, then with 6. A first request warms up the sign-in,
  # which loads the user only from the second request on.
  def query_counts(path_proc, **attributes)
    add_services(2, **attributes)
    get path_proc.call
    few = queries_for(path_proc.call)
    add_services(4, **attributes)
    [ few, queries_for(path_proc.call) ]
  end

  before { sign_in admin }

  it "doesn't grow with the services on the Client page" do
    few, many = query_counts(-> { fliip_user_path(client) })

    expect(many).to eq(few)
  end

  it "doesn't grow with the services on Mes services" do
    few, many = query_counts(-> { my_services_path })

    expect(many).to eq(few)
  end

  it "doesn't grow with the services on Échéances" do
    few, many = query_counts(-> { echeances_path }, expire_date: 10.days.from_now.to_date)

    expect(many).to eq(few)
  end

  it "doesn't grow with the services on an allocation's service list" do
    few, many = query_counts(-> { allocation_path(definition) })

    expect(many).to eq(few)
  end
end
