# Step 2 of 3 for one change per adjustment (docs/adr/0002): splits every old
# three-number row (séances used, absences used, extra séances) into one row
# per non-zero number, keeping its trainer and dates, with the note
# « Import initial ». The first number stays on the row itself; each further
# one becomes a new row.
#
# Every service's adjustment sums are compared before and after; any
# difference raises, which rolls the whole migration back. The old columns
# are left untouched (step 3 drops them), so the old code still reads the
# same totals until then.
class SplitServiceUsageAdjustments < ActiveRecord::Migration[8.1]
  NOTE = "Import initial".freeze
  TOLERANCE = 1e-9

  # Kinds as stored (ServiceUsageAdjustment.kinds).
  PAID_USED = 0
  FREE_USED = 1
  PAID_BONUS = 2
  FREE_BONUS = 3

  # Old column → kind, in the order the split takes them.
  OLD_COLUMNS = { "paid_used_delta" => PAID_USED, "free_used_delta" => FREE_USED, "bonus_sessions" => PAID_BONUS }.freeze

  class MigrationAdjustment < ActiveRecord::Base
    self.table_name = "service_usage_adjustments"
  end

  def up
    MigrationAdjustment.reset_column_information
    rows_before = MigrationAdjustment.count
    before = old_totals
    deleted = 0

    MigrationAdjustment.where(kind: nil).order(:id).find_each do |row|
      changes = OLD_COLUMNS.filter_map { |column, kind| [ kind, row[column].to_f ] unless row[column].to_f.zero? }
      if changes.empty?
        row.delete
        deleted += 1
        next
      end

      (kind, amount), *others = changes
      row.update_columns(kind: kind, amount: amount, note: NOTE, created_by_id: row.user_id)
      others.each do |other_kind, other_amount|
        MigrationAdjustment.insert!({ fliip_service_id: row.fliip_service_id, user_id: row.user_id, created_by_id: row.user_id,
                                      kind: other_kind, amount: other_amount, note: NOTE,
                                      created_at: row.created_at, updated_at: row.updated_at })
      end
    end

    after = new_totals
    check_totals!(before, after)
    say "Adjustments: #{rows_before} rows before, #{MigrationAdjustment.count} after, " \
        "#{deleted} empty rows deleted, #{before.size} services checked."
  end

  # Puts each row's amount back into its old column. Rows stay split, so the
  # totals stay equal. Roll back step 3 first: it brings the old columns back.
  def down
    MigrationAdjustment.reset_column_information
    if MigrationAdjustment.where(kind: FREE_BONUS).exists?
      raise ActiveRecord::IrreversibleMigration, "Les absences ajoutées n'ont pas de colonne dans l'ancien format."
    end

    # Every old column is rewritten, so a row split by `up` (which keeps its
    # old numbers) isn't counted twice.
    assignments = OLD_COLUMNS.map { |column, kind| "#{column} = CASE WHEN kind = #{kind} THEN amount END" }
    MigrationAdjustment.update_all(assignments.join(", "))
    MigrationAdjustment.update_all(kind: nil, amount: nil, note: nil, created_by_id: nil)
  end

  private

  # { service id => [paid used, free used, paid bonus, free bonus] }
  def old_totals
    MigrationAdjustment.group(:fliip_service_id)
                       .pluck(:fliip_service_id, Arel.sql("COALESCE(SUM(paid_used_delta), 0)"),
                              Arel.sql("COALESCE(SUM(free_used_delta), 0)"), Arel.sql("COALESCE(SUM(bonus_sessions), 0)"))
                       .to_h { |id, paid, free, bonus| [ id, [ paid.to_f, free.to_f, bonus.to_f, 0.0 ] ] }
  end

  def new_totals
    sums = MigrationAdjustment.group(:fliip_service_id, :kind).sum(:amount)
    sums.keys.map(&:first).uniq.index_with do |id|
      [ PAID_USED, FREE_USED, PAID_BONUS, FREE_BONUS ].map { |kind| sums[[ id, kind ]].to_f }
    end
  end

  # Services that only had all-zero rows vanish from the new totals: compare
  # them as zeros.
  def check_totals!(before, after)
    zeros = [ 0.0, 0.0, 0.0, 0.0 ]
    (before.keys | after.keys).each do |id|
      old = before.fetch(id, zeros)
      new = after.fetch(id, zeros)
      next if old.zip(new).all? { |a, b| (a - b).abs < TOLERANCE }

      raise "Service #{id}: adjustment totals changed from #{old.inspect} to #{new.inspect}. Nothing was migrated."
    end
  end
end
