require "rails_helper"

RSpec.describe FliipApi::NewClients do
  let(:client) { instance_double(FliipApi::Client) }
  let(:syncer) { instance_double(FliipApi::UserSyncer, call: instance_double(FliipApi::UserSyncer::Result, changed?: true)) }
  let(:service) { described_class.new(client: client, syncer: syncer) }

  def rows(ids)
    ids.map { |id| { user_id: id.to_s } }
  end

  before { allow(client).to receive(:staff).and_return([]) }

  it "syncs clients newer than the newest local client, reading only the pages it needs" do
    create(:fliip_user, remote_id: 103)
    pages = [ rows(106.downto(101)), rows(100.downto(95)) ]
    allow(client).to receive(:client_pages).and_return(pages.each)

    summary = service.call

    expect(syncer).to have_received(:call).with({ user_id: "106" })
    expect(syncer).to have_received(:call).with({ user_id: "104" })
    expect(syncer).not_to have_received(:call).with({ user_id: "103" })
    expect(summary.synced).to eq(3)
  end

  it "syncs every client when there are none locally" do
    allow(client).to receive(:client_pages).and_return([ rows([ 2, 1 ]) ].each)

    expect(service.call.synced).to eq(2)
  end

  it "syncs staff not stored yet, whatever their id" do
    create(:fliip_user, remote_id: 500)
    create(:fliip_user, remote_id: 7, user_role: "coach")
    allow(client).to receive(:client_pages).and_return([ rows([ 500 ]) ].each)
    allow(client).to receive(:staff).and_return(rows([ 7, 8 ]))

    service.call

    expect(syncer).to have_received(:call).with({ user_id: "8" }).once
    expect(syncer).not_to have_received(:call).with({ user_id: "7" })
  end

  it "lets a failed list raise" do
    allow(client).to receive(:client_pages).and_raise(FliipApi::Unavailable, "down")

    expect { service.call }.to raise_error(FliipApi::Unavailable)
  end
end
