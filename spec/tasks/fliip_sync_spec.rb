require "rails_helper"
require "rake"

RSpec.describe "fliip:sync" do
  let(:task) { Rake::Task["fliip:sync"] }

  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("fliip:sync") }
  before { task.reenable }

  it "runs the full sync inline and exits 0" do
    allow(FliipFullSyncJob).to receive(:perform_now).and_return(FliipApi::BatchSync::Summary.new(3, 1, [], []))

    expect { task.invoke }
      .to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      .and output("[Fliip Sync] 3 synced (1 changed), 0 not found in Fliip, 0 failed\n").to_stdout
  end

  it "reports the error and exits 1 when the sync fails" do
    allow(FliipFullSyncJob).to receive(:perform_now).and_raise(FliipApi::Unavailable, "down")

    expect { task.invoke }
      .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      .and output(/\[Fliip Sync\] FAILED: FliipApi::Unavailable: down/).to_stderr
  end
end
