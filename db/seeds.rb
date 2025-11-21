# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# puts "⏳ Clearing existing SignupCodes and Users..."
# SignupCode.delete_all
# User.delete_all
# puts "✅ Cleared database."

# puts "🛠 Seeding data..."

# # --- Admin ---
# admin_code = SignupCode.create!
# admin = User.create!(
#   first_name:         "Paul",
#   last_name:          "Lanza",
#   phone:              "4380000001",
#   address:            "123 Main St, Montréal, QC",
#   birthday:           Date.new(1990, 6, 26),
#   email:              "a@a.a",
#   password:           "aaaa1111",
#   signup_code_token:  admin_code.code,
#   role:               :admin
# )
# puts "  • Created Admin: #{admin.first_name} #{admin.last_name} (#{admin.email})"

# # --- Manager ---
# manager_code = SignupCode.create!
# manager = User.create!(
#   first_name:         "Roxanne",
#   last_name:          "Dubuc Duval",
#   phone:              "4380000002",
#   address:            "456 Elm St, Montréal, QC",
#   birthday:           Date.new(1991, 10, 8),
#   email:              "b@b.b",
#   password:           "aaaa1111",
#   signup_code_token:  manager_code.code,
#   role:               :manager
# )
# puts "  • Created Manager: #{manager.first_name} #{manager.last_name} (#{manager.email})"

# # --- Employees ---
# [
#   { first_name: "Alex",        last_name: "Parisien",    phone: "4380000003", email: "c@c.c", birth: Date.new(1995, 5, 15) },
#   { first_name: "Billy-Jean",  last_name: "Chim",        phone: "4380000004", email: "d@d.d", birth: Date.new(1992, 12, 20) },
#   { first_name: "Valérie",     last_name: "Niro",        phone: "4380000005", email: "e@e.e", birth: Date.new(1993, 3, 10) }
# ].each_with_index do |attrs, idx|
#   code  = SignupCode.create!
#   user  = User.create!(
#     first_name:         attrs[:first_name],
#     last_name:          attrs[:last_name],
#     phone:              attrs[:phone],
#     address:            "#{700 + idx} Sample St, Montréal, QC",
#     birthday:           attrs[:birth],
#     email:              attrs[:email],
#     password:           "aaaa1111",
#     signup_code_token:  code.code,
#     role:               :employee
#   )
#   puts "  • Created Employee: #{user.first_name} #{user.last_name} (#{user.email})"
# end
# User.first.update!(role: :super_admin)

# puts "🎉 Seeding complete!"
# puts "   → Users:        #{User.count}"
# puts "   → SignupCodes:  #{SignupCode.count}"

# frozen_string_literal: true

# Seed demo data for Sessions, Consultations, and ServiceUsageAdjustments.
# Assumptions:
# - Users and SignupCodes are already present.
# - FliipUsers / FliipServices / ServiceDefinitions are populated via the API sync.

SEED_NOTE_PREFIX = "[SEED]".freeze
ADJUSTMENT_SEED_ANCHOR = Time.zone.local(2000, 1, 1, 12, 0, 0)

puts "== Seeding demo data (sessions, consultations, adjustments) =="

# --------------------------------------------------------------------
# Full cleanup of seeded tables
# --------------------------------------------------------------------

puts "→ Deleting all sessions..."
Session.delete_all

puts "→ Deleting all consultations..."
Consultation.delete_all

puts "→ Deleting all service usage adjustments..."
ServiceUsageAdjustment.delete_all

# --------------------------------------------------------------------
# Helper methods
# --------------------------------------------------------------------

def remaining_total_capacity(service)
  # Uses FliipService's own helpers; nil becomes 0 via to_f.
  service.remaining_paid_sessions.to_f + service.remaining_free_sessions.to_f
end

def service_date_range(service)
  # Builds a reasonable date window for seeding sessions.
  base_start =
    service.start_date ||
    service.purchase_date&.to_date ||
    Date.current - 90.days

  base_end =
    service.expire_date ||
    (service.start_date && service.start_date + 180.days) ||
    Date.current + 90.days

  start_date = base_start
  end_date   = base_end

  if end_date < start_date
    start_date, end_date = end_date, start_date
  end

  [start_date, end_date]
end

def associatable_services_by_client
  # Services that can be reasonably associated:
  # - Have a start_date
  # - Grouped by client
  FliipService
    .where.not(start_date: nil)
    .includes(:fliip_user)
    .group_by(&:fliip_user_id)
end

seed_time = Time.zone.now

active_users = User.where(active: true).order(:id).to_a
if active_users.empty?
  puts "⚠️  No active users found. Skipping seeding."
  exit
end

# --------------------------------------------------------------------
# Choose a limited set of services by status
# --------------------------------------------------------------------

all_services = FliipService
  .includes(:service_definition, :fliip_user, :service_usage_adjustments, :sessions)
  .to_a

active_services    = all_services.select { |svc| svc.purchase_status == "A" }
inactive_services  = all_services.select { |svc| svc.purchase_status == "I" }
cancelled_services = all_services.select { |svc| svc.purchase_status == "C" }
stopped_services   = all_services.select { |svc| svc.purchase_status == "S" }

# Global caps for services we will seed against.
selected_services = []
selected_services.concat(active_services.sample([35, active_services.size].min))
selected_services.concat(stopped_services.sample([3, stopped_services.size].min))
selected_services.concat(inactive_services.sample([15, inactive_services.size].min))
selected_services.concat(cancelled_services.sample([2, cancelled_services.size].min))

selected_services.uniq!
puts "→ Total FliipServices available: #{all_services.size}"
puts "→ FliipServices selected for seeding: #{selected_services.size}"
puts "   - Active:    #{selected_services.count { |s| s.purchase_status == 'A' }}"
puts "   - Stopped:   #{selected_services.count { |s| s.purchase_status == 'S' }}"
puts "   - Inactive:  #{selected_services.count { |s| s.purchase_status == 'I' }}"
puts "   - Cancelled: #{selected_services.count { |s| s.purchase_status == 'C' }}"

# --------------------------------------------------------------------
# Seed Sessions
# --------------------------------------------------------------------

created_sessions = 0

selected_services.each_with_index do |service, idx|
  total_remaining = remaining_total_capacity(service)
  next if total_remaining <= 0.0

  max_sessions_for_service = total_remaining.floor
  next if max_sessions_for_service <= 0

  target_sessions = [max_sessions_for_service, rand(1..6)].min
  next if target_sessions <= 0

  start_date, end_date = service_date_range(service)
  next if start_date.blank? || end_date.blank? || end_date < start_date

  target_sessions.times do
    break if remaining_total_capacity(service) <= 0.0

    coach = active_users[(idx + created_sessions) % active_users.size]

    day    = rand(start_date..end_date)
    hour   = rand(8..19)
    minute = [0, 15, 30, 45].sample
    occurred_at = Time.zone.local(day.year, day.month, day.day, hour, minute)

    session = Session.new(
      user:          coach,
      created_by:    coach,
      fliip_user:    service.fliip_user,
      fliip_service: service,
      occurred_at:   occurred_at,
      duration:      1.0,
      present:       [true, true, true, false].sample, # ~75% present
      confirmed:     false
    )

    session.confirmed_at = nil
    session.note = "#{SEED_NOTE_PREFIX} Session seeded on #{seed_time.to_date} for demo."

    if session.save
      created_sessions += 1
    else
      # Uncomment for debugging:
      # puts "   Skipped session for service #{service.id}: #{session.errors.full_messages.join(', ')}"
    end
  end
end

puts "✅ Sessions seeded: #{created_sessions}"

# --------------------------------------------------------------------
# Seed Consultations (no FliipUser/FliipService associations)
# --------------------------------------------------------------------

puts "→ Preparing consultation data..."

services_by_client = associatable_services_by_client
fliip_users_for_association = FliipUser
  .where(id: services_by_client.keys)
  .order(:id)
  .to_a

generic_first_names = %w[Alexis Camille Maxime Chloé Philippe Élodie Julien Marie]
generic_last_names  = %w[Tremblay Gagnon Côté Bouchard Lavoie Morin Fortin Leblanc]
generic_notes       = [
  "Première rencontre",
  "Suivi de progression",
  "Révision des objectifs",
  "Bilan mensuel",
  "Consultation de reprise",
  "Séance d’évaluation",
  nil
]

created_consultations = 0

active_users.each do |user|
  total_for_user    = rand(15..20)
  associated_count  = (total_for_user * 0.8).round
  loose_count       = total_for_user - associated_count

  # Real-data consultations:
  # - Name/email/phone from a real FliipUser
  # - Date is 3–6 days BEFORE a real FliipService.start_date
  # - No FliipUser/FliipService associations yet
  associated_count.times do
    break if fliip_users_for_association.empty?

    client   = fliip_users_for_association.sample
    services = services_by_client[client.id]
    next if services.blank?

    svc = services.sample
    next if svc.start_date.blank?

    base_start  = svc.start_date
    consult_day = base_start - rand(3..6).days
    hour        = rand(8..19)
    minute      = [0, 15, 30, 45].sample
    occurred_at = Time.zone.local(consult_day.year, consult_day.month, consult_day.day, hour, minute)

    consultation = Consultation.new(
      user_id:         user.id,
      created_by_id:   user.id,
      fliip_user_id:   nil,  # no association yet
      fliip_service_id: nil, # no association yet
      first_name:      client.user_firstname,
      last_name:       client.user_lastname,
      email:           client.user_email,
      phone_number:    client.user_phone1,
      occurred_at:     occurred_at,
      confirmed:       false,
      present:         [true, false].sample,
      note:            "#{SEED_NOTE_PREFIX} Consultation seeded on #{seed_time.to_date} for #{client.user_firstname} #{client.user_lastname} (associatable, no association)."
    )

    consultation.confirmed_at = nil

    if consultation.save
      created_consultations += 1
    else
      # Uncomment for debugging:
      # puts "   Skipped consultation (real-data) for user #{user.id}: #{consultation.errors.full_messages.join(', ')}"
    end
  end

  # Loose consultations (no FliipUser association, generic names)
  loose_count.times do
    fname = generic_first_names.sample
    lname = generic_last_names.sample

    date       = Date.current - rand(0..90)
    hour       = rand(8..20)
    minute     = [0, 15, 30, 45].sample
    occurred_at = Time.zone.local(date.year, date.month, date.day, hour, minute)

    consultation = Consultation.new(
      user_id:         user.id,
      created_by_id:   user.id,
      fliip_user_id:   nil,
      fliip_service_id: nil,
      first_name:      fname,
      last_name:       lname,
      email:           "#{fname.downcase}.#{lname.downcase}@exemple.com",
      phone_number:    "514-#{rand(100..999)}-#{rand(1000..9999)}",
      occurred_at:     occurred_at,
      confirmed:       false,
      present:         [true, false].sample,
      note:            "#{SEED_NOTE_PREFIX} Consultation seeded on #{seed_time.to_date} (generic, no association)."
    )

    consultation.confirmed_at = nil

    if consultation.save
      created_consultations += 1
    else
      # Uncomment for debugging:
      # puts "   Skipped consultation (generic) for user #{user.id}: #{consultation.errors.full_messages.join(', ')}"
    end
  end
end

puts "✅ Consultations seeded: #{created_consultations}"

# --------------------------------------------------------------------
# Seed ServiceUsageAdjustments
# --------------------------------------------------------------------

puts "→ Seeding service usage adjustments..."

created_adjustments = 0

selected_services.each_with_index do |service, idx|
  base_allowed_paid  = service.paid_allowed_total.to_f
  base_allowed_free  = service.free_allowed_total.to_f
  current_paid_used  = service.paid_used_total.to_f
  current_free_used  = service.free_used_total.to_f
  current_bonus      = service.bonus_sessions_total.to_f

  total_allowed      = base_allowed_paid + base_allowed_free
  total_used         = current_paid_used + current_free_used
  remaining_total    = [total_allowed - total_used, 0.0].max

  max_bonus_remaining = [4.0 - current_bonus, 0.0].max

  next if remaining_total <= 0.0 && max_bonus_remaining <= 0.0

  rand(0..2).times do
    # Recompute in case previous adjustments changed the totals.
    base_allowed_paid  = service.paid_allowed_total.to_f
    base_allowed_free  = service.free_allowed_total.to_f
    current_paid_used  = service.paid_used_total.to_f
    current_free_used  = service.free_used_total.to_f
    current_bonus      = service.bonus_sessions_total.to_f

    total_allowed      = base_allowed_paid + base_allowed_free
    total_used         = current_paid_used + current_free_used
    remaining_total    = [total_allowed - total_used, 0.0].max
    max_bonus_remaining = [4.0 - current_bonus, 0.0].max

    paid_remaining = [base_allowed_paid - current_paid_used, 0.0].max
    free_remaining = [base_allowed_free - current_free_used, 0.0].max

    bonus_step = 0.0
    if max_bonus_remaining.positive?
      bonus_step = [0.5, 1.0].sample
      bonus_step = [bonus_step, max_bonus_remaining].min
    end

    paid_step = 0.0
    free_step = 0.0

    if remaining_total.positive?
      usage_step = [0.5, 1.0].sample
      usage_step = [usage_step, remaining_total].min

      if paid_remaining.positive? && free_remaining.positive?
        if [true, false].sample
          paid_step = [usage_step, paid_remaining].min
        else
          free_step = [usage_step, free_remaining].min
        end
      elsif paid_remaining.positive?
        paid_step = [usage_step, paid_remaining].min
      elsif free_remaining.positive?
        free_step = [usage_step, free_remaining].min
      end
    end

    next if bonus_step.zero? && paid_step.zero? && free_step.zero?

    staff_user = active_users[(idx + created_adjustments) % active_users.size]

    adjustment = ServiceUsageAdjustment.new(
      fliip_service:    service,
      user:             staff_user,
      paid_used_delta:  paid_step.zero? ? nil : paid_step,
      free_used_delta:  free_step.zero? ? nil : free_step,
      bonus_sessions:   bonus_step.zero? ? nil : bonus_step
    )

    adjustment.created_at = ADJUSTMENT_SEED_ANCHOR
    adjustment.updated_at = ADJUSTMENT_SEED_ANCHOR

    if adjustment.save
      created_adjustments += 1
    else
      # Uncomment for debugging:
      # puts "   Skipped adjustment for service #{service.id}: #{adjustment.errors.full_messages.join(', ')}"
    end
  end
end

puts "✅ Service usage adjustments seeded: #{created_adjustments}"
puts "🎉 Seeding complete."
