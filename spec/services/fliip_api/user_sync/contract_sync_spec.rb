require "rails_helper"

RSpec.describe FliipApi::UserSync::ContractSync do
  let(:api)    { instance_double(FliipApi::ApiClient) }
  let(:client) { create(:fliip_user, remote_id: 900) }

  let(:current) do
    { contract_id: "11", status: "A", start_date: "2026-01-01", end_date: "2026-12-31",
      membership_name: "Mensuel", stop_date: nil, pack_class_num: "10" }
  end
  let(:future)  { { contract_id: "12", status: "P", start_date: "2027-01-01" } }
  let(:history) { { contract_id: "13", status: "C", cancel_date: "2025-06-01" } }

  before do
    allow(FliipApi::ApiClient).to receive(:new).and_return(api)
    allow(api).to receive_messages(
      fetch_user_contracts: [current],
      fetch_future_user_contracts: [future],
      fetch_history_user_contracts: [history]
    )
  end

  it "stores current, future and past contracts for the client's remote id" do
    described_class.call(client)

    expect(api).to have_received(:fetch_user_contracts).with(900)
    expect(api).to have_received(:fetch_future_user_contracts).with(900)
    expect(api).to have_received(:fetch_history_user_contracts).with(900)
    expect(client.fliip_contracts.pluck(:remote_contract_id)).to contain_exactly(11, 12, 13)

    contract = FliipContract.find_by!(remote_contract_id: 11)
    expect(contract).to have_attributes(
      status: "A", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31),
      membership_name: "Mensuel", stop_date: nil, pack_class_num: "10"
    )
    expect(FliipContract.find_by!(remote_contract_id: 13).cancel_date).to eq(Date.new(2025, 6, 1))
  end

  it "updates a known contract instead of duplicating it" do
    described_class.call(client)
    current[:status] = "S"

    described_class.call(client)

    expect(FliipContract.count).to eq(3)
    expect(FliipContract.find_by!(remote_contract_id: 11).status).to eq("S")
  end

  it "does not touch a contract that has not changed" do
    described_class.call(client)
    contract = FliipContract.find_by!(remote_contract_id: 11)
    contract.update_columns(updated_at: 1.day.ago)

    expect { described_class.call(client) }.not_to(change { contract.reload.updated_at })
  end

  it "stores nothing when the API returns no contracts" do
    allow(api).to receive_messages(fetch_user_contracts: [], fetch_future_user_contracts: [], fetch_history_user_contracts: [])

    expect { described_class.call(client) }.not_to change(FliipContract, :count)
  end
end
