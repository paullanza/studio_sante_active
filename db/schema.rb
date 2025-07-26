# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_07_26_194453) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "fliip_contracts", force: :cascade do |t|
    t.bigint "remote_contract_id"
    t.bigint "fliip_user_id", null: false
    t.string "status"
    t.date "start_date"
    t.date "end_date"
    t.date "stop_date"
    t.date "resume_date"
    t.date "cancel_date"
    t.string "rebate"
    t.string "discount_name"
    t.string "main_user_contract"
    t.string "membership_name"
    t.string "plan_base_type"
    t.string "plan_type"
    t.text "plan_description"
    t.string "plan_classes"
    t.string "payment_terms"
    t.string "duration"
    t.string "billed_at_purchase"
    t.string "ledger_account"
    t.string "pack_class_num"
    t.string "pack_class_used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fliip_user_id"], name: "index_fliip_contracts_on_fliip_user_id"
    t.index ["remote_contract_id"], name: "index_fliip_contracts_on_remote_contract_id"
  end

  create_table "fliip_services", force: :cascade do |t|
    t.bigint "remote_purchase_id"
    t.bigint "fliip_user_id", null: false
    t.string "purchase_status"
    t.date "start_date"
    t.date "expire_date"
    t.datetime "purchase_date"
    t.date "stop_date"
    t.date "cancel_date"
    t.string "rebate"
    t.boolean "stop_payments"
    t.string "discount_name"
    t.integer "service_id"
    t.string "service_name"
    t.string "service_type"
    t.string "service_category_name"
    t.string "coach"
    t.string "payment_terms"
    t.string "duration"
    t.string "online_enabled"
    t.string "service_description"
    t.integer "billed_at_purchase"
    t.string "ledger_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fliip_user_id"], name: "index_fliip_services_on_fliip_user_id"
    t.index ["remote_purchase_id"], name: "index_fliip_services_on_remote_purchase_id"
  end

  create_table "fliip_users", force: :cascade do |t|
    t.bigint "remote_id"
    t.string "custom_id"
    t.string "user_role"
    t.string "user_firstname"
    t.string "user_lastname"
    t.string "user_gender"
    t.string "member_type"
    t.string "user_status"
    t.string "user_email"
    t.string "user_image"
    t.string "user_phone1"
    t.string "user_phone2"
    t.date "user_dob"
    t.string "user_address"
    t.string "user_city"
    t.string "user_zipcode"
    t.string "user_language"
    t.string "profile_step"
    t.date "member_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["remote_id"], name: "index_fliip_users_on_remote_id"
  end

  add_foreign_key "fliip_contracts", "fliip_users"
  add_foreign_key "fliip_services", "fliip_users"
end
