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

ActiveRecord::Schema[8.1].define(version: 2026_11_03_172501) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "unaccent"

  create_table "consultations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "created_by_id", null: false
    t.bigint "fliip_user_id"
    t.bigint "fliip_service_id"
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone_number"
    t.datetime "confirmed_at"
    t.boolean "confirmed"
    t.boolean "present"
    t.datetime "occurred_at"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_consultations_on_created_by_id"
    t.index ["fliip_service_id"], name: "index_consultations_on_fliip_service_id"
    t.index ["fliip_user_id"], name: "index_consultations_on_fliip_user_id"
    t.index ["user_id"], name: "index_consultations_on_user_id"
  end

  create_table "fliip_contracts", force: :cascade do |t|
    t.bigint "remote_contract_id", null: false
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
    t.datetime "missing_from_fliip_at"
    t.index ["fliip_user_id"], name: "index_fliip_contracts_on_fliip_user_id"
    t.index ["remote_contract_id"], name: "index_fliip_contracts_on_remote_contract_id", unique: true
  end

  create_table "fliip_services", force: :cascade do |t|
    t.bigint "remote_purchase_id", null: false
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
    t.datetime "missing_from_fliip_at"
    t.index ["fliip_user_id"], name: "index_fliip_services_on_fliip_user_id"
    t.index ["remote_purchase_id"], name: "index_fliip_services_on_remote_purchase_id", unique: true
  end

  create_table "fliip_users", force: :cascade do |t|
    t.bigint "remote_id", null: false
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
    t.datetime "missing_from_fliip_at"
    t.index ["remote_id"], name: "index_fliip_users_on_remote_id", unique: true
  end

  create_table "service_definitions", force: :cascade do |t|
    t.integer "service_id"
    t.string "service_name"
    t.integer "paid_sessions"
    t.integer "free_sessions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "service_usage_adjustments", force: :cascade do |t|
    t.bigint "fliip_service_id", null: false
    t.bigint "user_id", null: false
    t.float "paid_used_delta"
    t.float "free_used_delta"
    t.float "bonus_sessions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fliip_service_id"], name: "index_service_usage_adjustments_on_fliip_service_id"
    t.index ["user_id"], name: "index_service_usage_adjustments_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "fliip_user_id", null: false
    t.bigint "fliip_service_id", null: false
    t.bigint "created_by_id", null: false
    t.datetime "confirmed_at"
    t.boolean "present"
    t.text "note"
    t.boolean "confirmed"
    t.integer "session_type", null: false
    t.float "duration", default: 1.0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "occurred_at"
    t.index ["created_by_id"], name: "index_sessions_on_created_by_id"
    t.index ["fliip_service_id"], name: "index_sessions_on_fliip_service_id"
    t.index ["fliip_user_id"], name: "index_sessions_on_fliip_user_id"
    t.index ["occurred_at"], name: "index_sessions_on_occurred_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "signup_codes", force: :cascade do |t|
    t.string "code", null: false
    t.integer "status", default: 0, null: false
    t.datetime "expiry_date", null: false
    t.bigint "used_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_signup_codes_on_code", unique: true
    t.index ["used_by_id"], name: "index_signup_codes_on_used_by_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.string "address"
    t.date "birthday"
    t.integer "role", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "consultations", "fliip_services", on_delete: :nullify
  add_foreign_key "consultations", "fliip_users", on_delete: :nullify
  add_foreign_key "consultations", "users"
  add_foreign_key "consultations", "users", column: "created_by_id"
  add_foreign_key "fliip_contracts", "fliip_users"
  add_foreign_key "fliip_services", "fliip_users"
  add_foreign_key "service_usage_adjustments", "fliip_services"
  add_foreign_key "service_usage_adjustments", "users"
  add_foreign_key "sessions", "fliip_services"
  add_foreign_key "sessions", "fliip_users"
  add_foreign_key "sessions", "users"
  add_foreign_key "sessions", "users", column: "created_by_id"
  add_foreign_key "signup_codes", "users", column: "used_by_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
