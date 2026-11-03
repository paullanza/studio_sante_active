require "rails_helper"

RSpec.describe FliipApi::BatchSync do
  let(:syncer)    { instance_double(FliipApi::UserSyncer) }
  let(:batch)     { described_class.new(syncer: syncer) }
  let(:changed)   { instance_double(FliipApi::UserSyncer::Result, changed?: true) }
  let(:unchanged) { instance_double(FliipApi::UserSyncer::Result, changed?: false) }

  it "syncs rows with call and remote ids with call_by_remote_id" do
    allow(syncer).to receive(:call).with({ user_id: "1" }).and_return(changed)
    allow(syncer).to receive(:call_by_remote_id).with(2).and_return(unchanged)

    summary = batch.call([ { user_id: "1" }, 2 ])

    expect(summary).to have_attributes(synced: 2, changed: 1, not_found: [], failed: [])
  end

  it "records users Fliip no longer knows and keeps going" do
    allow(syncer).to receive(:call_by_remote_id).with(1).and_raise(FliipApi::NotFound, "400")
    allow(syncer).to receive(:call_by_remote_id).with(2).and_return(unchanged)

    expect(batch.call([ 1, 2 ])).to have_attributes(synced: 1, not_found: [ 1 ])
  end

  it "records a failed user and keeps going" do
    allow(syncer).to receive(:call_by_remote_id).with(1).and_raise(FliipApi::Unavailable, "timeout")
    allow(syncer).to receive(:call_by_remote_id).with(2).and_return(unchanged)

    summary = batch.call([ 1, 2 ])

    expect(summary.synced).to eq(1)
    expect(summary.failed).to eq([ "1: FliipApi::Unavailable: timeout" ])
  end

  it "stops after 20 failures in a row" do
    allow(syncer).to receive(:call_by_remote_id).and_raise(FliipApi::Unavailable, "down")

    expect { batch.call((1..30).to_a) }.to raise_error(FliipApi::Unavailable, /20 failures in a row/)
    expect(syncer).to have_received(:call_by_remote_id).exactly(20).times
  end

  it "summarises itself" do
    summary = described_class::Summary.new(3, 1, [ 9 ], [])

    expect(summary.to_s).to eq("3 synced (1 changed), 1 not found in Fliip, 0 failed")
    expect(summary.merge(summary)).to have_attributes(synced: 6, changed: 2, not_found: [ 9, 9 ])
  end
end
