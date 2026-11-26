# Who confirmed a séance for payroll. Nullable: older confirmations stay
# « par — ». The sessions table is the app's largest, so the index is built
# concurrently (outside a transaction) and the foreign key is validated in a
# second step, neither blocking writes.
class AddConfirmedByToSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :sessions, :confirmed_by_id, :bigint
    add_index :sessions, :confirmed_by_id, algorithm: :concurrently
    add_foreign_key :sessions, :users, column: :confirmed_by_id, validate: false
    validate_foreign_key :sessions, column: :confirmed_by_id
  end

  def down
    remove_foreign_key :sessions, column: :confirmed_by_id
    remove_index :sessions, :confirmed_by_id, algorithm: :concurrently
    remove_column :sessions, :confirmed_by_id
  end
end
