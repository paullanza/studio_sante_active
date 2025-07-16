class CreateFliipUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :fliip_users do |t|
      t.bigint :remote_id
      t.string :custom_id
      t.string :user_role
      t.string :user_firstname
      t.string :user_lastname
      t.string :user_gender
      t.string :member_type
      t.string :user_status
      t.string :user_email
      t.string :user_image
      t.string :user_phone1
      t.string :user_phone2
      t.date :user_dob
      t.string :user_address
      t.string :user_city
      t.string :user_zipcode
      t.string :user_language
      t.string :profile_step
      t.string :sync_g_cal
      t.date :member_since
      t.string :custom_field_value
      t.string :custom_field_option

      t.timestamps
    end
    add_index :fliip_users, :remote_id
  end
end
