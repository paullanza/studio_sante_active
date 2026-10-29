require "rails_helper"

RSpec.describe FliipApi::UserSync::UserImporter do
  let(:api) { instance_double(FliipApi::ApiClient) }

  let(:api_user) do
    { user_id: "123", user_firstname: "Marie", user_lastname: "Tremblay",
      user_email: "marie@example.com", user_role: "user", user_dob: "1990-05-01" }
  end

  let(:api_service) do
    { service_purchase_id: "777", service_id: "42", service_name: "Entraînement privé",
      purchase_status: "A", start_date: "2026-09-01", expire_date: "2026-12-01",
      purchase_date: "2026-08-30 14:00:00", stop_payments: "0" }
  end

  let(:api_contract) do
    { contract_id: "555", status: "A", start_date: "2026-01-01", end_date: "2026-12-31",
      membership_name: "Mensuel" }
  end

  before do
    allow(FliipApi::ApiClient).to receive(:new).and_return(api)
    allow(api).to receive_messages(
      fetch_all_users: [api_user],
      fetch_all_staff: [],
      fetch_user_contracts: [api_contract],
      fetch_future_user_contracts: [],
      fetch_history_user_contracts: [],
      fetch_user_services: [api_service],
      fetch_future_user_services: [],
      fetch_history_user_services: []
    )
  end

  it "creates the client with their services and contracts" do
    message = described_class.call

    client = FliipUser.find_by!(remote_id: 123)
    expect(client.full_name).to eq("Marie Tremblay")
    expect(client.user_dob).to eq(Date.new(1990, 5, 1))

    service = client.fliip_services.sole
    expect(service.remote_purchase_id).to eq(777)
    expect(service.service_id).to eq(42)
    expect(service.start_date).to eq(Date.new(2026, 9, 1))
    expect(service.stop_payments).to be false
    # Fliip sends a zoneless timestamp; it is stored as-is, read as UTC
    expect(service.purchase_date).to eq(Time.utc(2026, 8, 30, 14, 0, 0))

    expect(client.fliip_contracts.sole.status).to eq("A")
    expect(message).to include("1 new user, 0 updated users")
  end

  it "creates a service definition for new service types" do
    described_class.call

    definition = ServiceDefinition.find_by!(service_id: 42)
    expect(definition.service_name).to eq("Entraînement privé")
    expect(definition.paid_sessions).to eq(0)
  end

  it "updates existing records instead of duplicating them" do
    described_class.call
    api_user[:user_lastname] = "Gagnon"
    api_service[:purchase_status] = "C"

    message = described_class.call

    expect(FliipUser.count).to eq(1)
    expect(FliipUser.sole.user_lastname).to eq("Gagnon")
    expect(FliipService.count).to eq(1)
    expect(FliipService.sole.purchase_status).to eq("C")
    expect(message).to include("0 new users, 1 updated user")
  end

  it "keeps going when a date from the API is invalid" do
    api_user[:user_dob] = "not a date"

    described_class.call

    expect(FliipUser.sole.user_dob).to be_nil
  end
end
