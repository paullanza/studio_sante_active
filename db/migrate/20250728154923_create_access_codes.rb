class CreateAccessCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :access_codes do |t|
      t.string :code
      t.references :user, null: false, foreign_key: true
      t.datetime :used_at
      t.boolean :active

      t.timestamps
    end
  end
end
