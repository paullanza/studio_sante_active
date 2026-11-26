require "rails_helper"
require Rails.root.join("db/migrate/20261126200304_split_service_usage_adjustments")
require Rails.root.join("db/migrate/20261126200306_finalize_one_change_adjustments")

# Runs the data migration against old three-number rows. Step 3 is rolled back
# first to bring the old columns back; Postgres DDL is transactional, so the
# spec's transaction undoes it all.
RSpec.describe SplitServiceUsageAdjustments do
  let(:migration) { described_class.new }
  let(:table) { described_class::MigrationAdjustment }
  let(:trainer) { create(:user) }
  let(:service) { create(:fliip_service) }
  let(:other_service) { create(:fliip_service) }
  let(:created_at) { Time.zone.local(2026, 3, 2, 10, 0) }

  before do
    ActiveRecord::Migration.suppress_messages { FinalizeOneChangeAdjustments.new.migrate(:down) }
    table.reset_column_information
  end

  after { ServiceUsageAdjustment.reset_column_information }

  def old_row(fliip_service, paid: nil, free: nil, bonus: nil)
    { fliip_service_id: fliip_service.id, user_id: trainer.id, paid_used_delta: paid, free_used_delta: free,
      bonus_sessions: bonus, created_at: created_at, updated_at: created_at }
  end

  def up
    ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
  end

  def sums(fliip_service)
    table.where(fliip_service_id: fliip_service.id).group(:kind).sum(:amount)
  end

  it "splits a three-number row into three rows with the same totals" do
    table.insert_all!([ old_row(service, paid: 4, free: 0.5, bonus: 2) ])

    up

    rows = table.where(fliip_service_id: service.id).order(:kind)
    expect(rows.map { |r| [ r.kind, r.amount ] }).to eq([ [ 0, 4.0 ], [ 1, 0.5 ], [ 2, 2.0 ] ])
    expect(rows.map { |r| [ r.user_id, r.created_by_id, r.note, r.created_at ] }.uniq)
      .to eq([ [ trainer.id, trainer.id, "Import initial", created_at ] ])
  end

  it "keeps a one-number row as one row, and adds up several rows per service" do
    table.insert_all!([ old_row(service, paid: -1, free: 0, bonus: nil), old_row(service, paid: 3), old_row(other_service, bonus: 1.5) ])

    up

    expect(table.where(fliip_service_id: service.id).count).to eq(2)
    expect(sums(service)).to eq(0 => 2.0)
    expect(sums(other_service)).to eq(2 => 1.5)
  end

  it "deletes an all-zero row" do
    table.insert_all!([ old_row(service, paid: 0, free: nil, bonus: 0) ])

    up

    expect(table.where(fliip_service_id: service.id)).to be_empty
  end

  it "rolls everything back when a total differs" do
    table.insert_all!([ old_row(service, paid: 4, free: 1) ])
    allow(migration).to receive(:new_totals).and_wrap_original do |original|
      original.call.tap { |totals| totals[service.id][0] += 1 }
    end

    expect { up }.to raise_error(/Service #{service.id}: adjustment totals changed/)
  end

  it "puts the amounts back in the old columns on the way down" do
    table.insert_all!([ old_row(service, paid: 4, free: 0.5, bonus: 2) ])
    up

    ActiveRecord::Migration.suppress_messages { migration.migrate(:down) }

    totals = table.where(fliip_service_id: service.id)
                  .pluck(Arel.sql("SUM(paid_used_delta)"), Arel.sql("SUM(free_used_delta)"), Arel.sql("SUM(bonus_sessions)")).first
    expect(totals).to eq([ 4.0, 0.5, 2.0 ])
    expect(table.where.not(kind: nil)).to be_empty
  end
end
