# Fliip remote IDs must be unique and present locally: the sync upserts by
# them. Production was checked for duplicates before this ran; blanks and
# duplicates are checked again here so the migration stops with a clear
# message instead of a half-applied state.
class MakeFliipRemoteIdsUnique < ActiveRecord::Migration[8.1]
  COLUMNS = {
    fliip_users: :remote_id,
    fliip_services: :remote_purchase_id,
    fliip_contracts: :remote_contract_id
  }.freeze

  def up
    COLUMNS.each do |table, column|
      blanks = select_value("SELECT COUNT(*) FROM #{table} WHERE #{column} IS NULL").to_i
      dupes = select_value("SELECT COUNT(*) FROM (SELECT #{column} FROM #{table} GROUP BY #{column} HAVING COUNT(*) > 1) d").to_i
      if blanks.positive? || dupes.positive?
        raise "#{table}.#{column}: #{blanks} blank and #{dupes} duplicated values. Clean them up before running this migration."
      end
    end

    COLUMNS.each do |table, column|
      remove_index table, column
      add_index table, column, unique: true
      change_column_null table, column, false
    end
  end

  def down
    COLUMNS.each do |table, column|
      change_column_null table, column, true
      remove_index table, column
      add_index table, column
    end
  end
end
