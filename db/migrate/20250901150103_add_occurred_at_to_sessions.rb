class AddOccurredAtToSessions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    add_column :sessions, :occurred_at, :datetime

    # Backfill from existing date + time without loading rows in Ruby
    execute <<-SQL
      UPDATE sessions
      SET occurred_at = (date + time)
      WHERE occurred_at IS NULL
        AND date IS NOT NULL
        AND time IS NOT NULL;
    SQL

    add_index :sessions, :occurred_at
  end

  def down
    remove_index :sessions, :occurred_at
    remove_column :sessions, :occurred_at
  end
end
