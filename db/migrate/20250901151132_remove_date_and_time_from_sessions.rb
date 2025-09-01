class RemoveDateAndTimeFromSessions < ActiveRecord::Migration[7.1]
  def up
    remove_column :sessions, :date, :date
    remove_column :sessions, :time, :time
  end

  def down
    add_column :sessions, :date, :date
    add_column :sessions, :time, :time

    # Best-effort backfill from occurred_at
    execute <<-SQL
      UPDATE sessions
      SET
        date = occurred_at::date,
        time = occurred_at::time
      WHERE occurred_at IS NOT NULL;
    SQL
  end
end
