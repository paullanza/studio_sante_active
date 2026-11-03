# Fliip never reports deletions. The sync sets this when Fliip stops
# returning a record, and clears it if the record comes back.
class AddMissingFromFliipAtToFliipTables < ActiveRecord::Migration[8.1]
  def change
    add_column :fliip_users, :missing_from_fliip_at, :datetime
    add_column :fliip_services, :missing_from_fliip_at, :datetime
    add_column :fliip_contracts, :missing_from_fliip_at, :datetime
  end
end
