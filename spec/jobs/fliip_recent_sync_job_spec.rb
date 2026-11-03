require "rails_helper"

RSpec.describe FliipRecentSyncJob do
  let(:client) { instance_double(FliipApi::Client) }
  let(:syncer) { instance_double(FliipApi::UserSyncer) }
  let(:result) { instance_double(FliipApi::UserSyncer::Result, changed?: false) }
  let(:new_clients) { instance_double(FliipApi::NewClients, call: FliipApi::BatchSync::Summary.empty) }

  before do
    allow(FliipApi::Client).to receive(:new).and_return(client)
    allow(FliipApi::UserSyncer).to receive(:new).with(client: client).and_return(syncer)
    allow(FliipApi::NewClients).to receive(:new).with(client: client, syncer: syncer).and_return(new_clients)
    allow(syncer).to receive(:call_by_remote_id).and_return(result)
  end

  it "syncs new clients, then owners of services or contracts that ended in the last 30 days" do
    ended_service  = create(:fliip_service, expire_date: 10.days.ago.to_date).fliip_user
    ended_contract = create(:fliip_contract, end_date: 29.days.ago.to_date).fliip_user
    create(:fliip_service, expire_date: 31.days.ago.to_date)
    create(:fliip_service, expire_date: 1.year.from_now.to_date)

    summary = described_class.perform_now

    expect(new_clients).to have_received(:call)
    expect(syncer).to have_received(:call_by_remote_id).with(ended_service.remote_id)
    expect(syncer).to have_received(:call_by_remote_id).with(ended_contract.remote_id)
    expect(syncer).to have_received(:call_by_remote_id).twice
    expect(summary.synced).to eq(2)
  end

  it "raises at the end when a user failed, so the run shows as failed" do
    user = create(:fliip_service, expire_date: 1.day.ago.to_date).fliip_user
    allow(syncer).to receive(:call_by_remote_id).with(user.remote_id).and_raise(FliipApi::Unavailable, "timeout")

    expect { described_class.perform_now }.to raise_error(FliipApi::PartialSync, /#{user.remote_id}: FliipApi::Unavailable/)
  end

  it "shares the Fliip concurrency key with the full sync" do
    expect(described_class.concurrency_key).to eq(FliipFullSyncJob.concurrency_key)
    expect(described_class.concurrency_group).to eq("FliipSync")
  end
end
