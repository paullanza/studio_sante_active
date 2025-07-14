class CreateFliipUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :fliip_users do |t|
      t.bigint :remote_id
      t.string :custom_id
      t.string :user_role
      t.string :first_name
      t.string :last_name
      t.string :gender
      t.string :member_type
      t.string :status
      t.string :email
      t.string :image
      t.string :phone1
      t.string :phone2
      t.date :dob
      t.string :address
      t.string :city
      t.string :zipcode
      t.string :language
      t.string :profile_step
      t.string :sync_g_cal
      t.float :progress
      t.date :member_since
      t.string :custom_field_value
      t.string :custom_field_option

      t.timestamps
    end
    add_index :fliip_users, :remote_id
  end
end
