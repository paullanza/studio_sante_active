class CreateServiceDefinitions < ActiveRecord::Migration[7.1]
  def change
    create_table :service_definitions do |t|
      t.integer :service_id
      t.string :service_name
      t.integer :paid_sessions
      t.integer :free_sessions

      t.timestamps
    end
  end
end
