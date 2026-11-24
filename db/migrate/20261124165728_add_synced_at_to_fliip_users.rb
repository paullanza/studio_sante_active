class AddSyncedAtToFliipUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :fliip_users, :synced_at, :datetime
  end
end
