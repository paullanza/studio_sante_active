require "rails_helper"

RSpec.describe FliipFullSyncJob do
  let(:client) { instance_double(FliipApi::Client) }
  let(:syncer) { instance_double(FliipApi::UserSyncer) }
  let(:result) { instance_double(FliipApi::UserSyncer::Result, changed?: true) }

  before do
    allow(FliipApi::Client).to receive(:new).and_return(client)
    allow(FliipApi::UserSyncer).to receive(:new).with(client: client).and_return(syncer)
    allow(syncer).to receive_messages(call: result, call_by_remote_id: result)
  end

  it "syncs every client and staff member from the lists" do
    allow(client).to receive_messages(clients: [ { user_id: "2" }, { user_id: "1" } ], staff: [ { user_id: "9" } ])

    summary = described_class.perform_now

    expect(syncer).to have_received(:call).exactly(3).times
    expect(summary).to have_attributes(synced: 3, changed: 3)
  end

  it "checks local users missing from the lists one by one, skipping those already flagged" do
    listed = create(:fliip_user, remote_id: 1)
    unlisted = create(:fliip_user, remote_id: 2)
    create(:fliip_user, :missing_from_fliip, remote_id: 3)
    allow(client).to receive_messages(clients: [ { user_id: listed.remote_id.to_s } ], staff: [])
    allow(syncer).to receive(:call_by_remote_id).with(unlisted.remote_id).and_raise(FliipApi::NotFound, "400")

    summary = described_class.perform_now

    expect(syncer).to have_received(:call_by_remote_id).once
    expect(summary.not_found).to eq([ unlisted.remote_id ])
  end

  it "stops before syncing anyone when a list fails" do
    allow(client).to receive(:clients).and_return([ { user_id: "1" } ])
    allow(client).to receive(:staff).and_raise(FliipApi::Unavailable, "down")

    expect { described_class.perform_now }.to raise_error(FliipApi::Unavailable)
    expect(syncer).not_to have_received(:call)
  end
end
