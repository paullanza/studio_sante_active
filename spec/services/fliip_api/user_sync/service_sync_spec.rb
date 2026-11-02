require "rails_helper"

RSpec.describe FliipApi::UserSync::ServiceSync do
  let(:api)    { instance_double(FliipApi::ApiClient) }
  let(:client) { create(:fliip_user, remote_id: 900) }

  let(:current) do
    { service_purchase_id: "21", service_id: "42", service_name: "Kinésiologie", purchase_status: "A",
      start_date: "2026-08-23", expire_date: "2027-08-23", purchase_date: "2026-08-23 08:34:54",
      stop_payments: "1", billed_at_purchase: "1", coach: "Alexandre Tremblay" }
  end
  let(:future)  { { service_purchase_id: "22", service_id: "42", purchase_status: "P", stop_payments: "0" } }
  let(:history) { { service_purchase_id: "23", service_id: "43", purchase_status: "I", expire_date: nil } }

  before do
    allow(FliipApi::ApiClient).to receive(:new).and_return(api)
    allow(api).to receive_messages(
      fetch_user_services: [current],
      fetch_future_user_services: [future],
      fetch_history_user_services: [history]
    )
  end

  it "stores current, future and past services for the client's remote id" do
    described_class.call(client)

    expect(api).to have_received(:fetch_user_services).with(900)
    expect(api).to have_received(:fetch_future_user_services).with(900)
    expect(api).to have_received(:fetch_history_user_services).with(900)
    expect(client.fliip_services.pluck(:remote_purchase_id)).to contain_exactly(21, 22, 23)

    service = FliipService.find_by!(remote_purchase_id: 21)
    expect(service).to have_attributes(
      service_id: 42, service_name: "Kinésiologie", purchase_status: "A",
      start_date: Date.new(2026, 8, 23), expire_date: Date.new(2027, 8, 23),
      purchase_date: Time.utc(2026, 8, 23, 8, 34, 54), stop_payments: true,
      billed_at_purchase: 1, coach: "Alexandre Tremblay"
    )
    expect(FliipService.find_by!(remote_purchase_id: 22).stop_payments).to be false
  end

  it "updates a known service instead of duplicating it" do
    described_class.call(client)
    current[:purchase_status] = "C"

    described_class.call(client)

    expect(FliipService.count).to eq(3)
    expect(FliipService.find_by!(remote_purchase_id: 21)).to be_cancelled
  end

  it "does not touch a service that has not changed" do
    described_class.call(client)
    service = FliipService.find_by!(remote_purchase_id: 21)
    service.update_columns(updated_at: 1.day.ago)

    expect { described_class.call(client) }.not_to(change { service.reload.updated_at })
  end
end
