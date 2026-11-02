require "rails_helper"
require "rake"

RSpec.describe "fliip:sync" do
  let(:task) { Rake::Task["fliip:sync"] }

  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("fliip:sync") }
  before { task.reenable }

  it "runs the full import and exits 0" do
    allow(FliipApi::UserSync::UserImporter).to receive(:call).and_return("Sync complete")

    expect { task.invoke }
      .to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      .and output("[Fliip Sync] Sync complete\n").to_stdout
    expect(FliipApi::UserSync::UserImporter).to have_received(:call)
  end

  it "reports the error and exits 1 when the import fails" do
    allow(FliipApi::UserSync::UserImporter).to receive(:call).and_raise(RuntimeError, "boom")

    expect { task.invoke }
      .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      .and output(/\[Fliip Sync\] FAILED: RuntimeError: boom/).to_stderr
  end
end
