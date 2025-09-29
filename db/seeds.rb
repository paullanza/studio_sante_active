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

# puts "🛠 Seeding sessions and service usage adjustments…"

# # --- helpers --------------------------------------------------------------

# def eligible_services
#   today = Time.zone.today
#   cutoff = 11.months.ago.to_date
#   scope = FliipService
#             .where("start_date >= ?", cutoff)
#             .where("expire_date > ?", today)
#   # If you maintain an explicit "active" flag via purchase_status, uncomment:
#   # scope = scope.where(purchase_status: ["active", "running", "in_progress"])
#   scope.includes(:fliip_user)
# end

# def staff_pool
#   User.where(active: true) # keep it broad; roles are enforced elsewhere
#       .order(:id)
#       .to_a
# end

# def allowed_capacity_for(service)
#   sd = ServiceDefinition.find_by(service_id: service.service_id)
#   (sd&.paid_sessions.to_i + sd&.free_sessions.to_i)
# end

# def totals_from_adjustments(service)
#   rel = ServiceUsageAdjustment.where(fliip_service_id: service.id)
#   bonus = rel.sum(:bonus_sessions).to_f
#   used_delta = rel.sum("COALESCE(paid_used_delta,0) + COALESCE(free_used_delta,0)").to_f
#   [bonus, used_delta]
# end

# def current_used_sessions(service)
#   Session.where(fliip_service_id: service.id).count
# end

# def remaining_capacity(service)
#   base_allowed = allowed_capacity_for(service)
#   bonus, used_delta = totals_from_adjustments(service)
#   used_sessions = current_used_sessions(service)
#   remaining = (base_allowed + bonus) - (used_sessions + used_delta)
#   remaining.floor # sessions are whole-count; keep it conservative
# end

# def session_enum_name
#   # Choose a valid enum name deterministically (first key).
#   Session.session_types.keys.first
# end

# # Keep a simple in-memory schedule to avoid overlaps per seeding run.
# require "set"
# staff_busy  = Hash.new { |h, k| h[k] = Set.new }
# client_busy = Hash.new { |h, k| h[k] = Set.new }

# def slot_busy?(busy_set, at_time)
#   busy_set.include?(at_time)
# end

# def mark_busy!(busy_set, at_time)
#   busy_set << at_time
# end

# def pick_time_in_range(rng, start_date:, end_date:)
#   day = rng.rand(start_date..end_date)
#   hour = rng.rand(9..19) # 9:00-19:00 inclusive
#   Time.zone.local(day.year, day.month, day.day, hour, 0, 0)
# end

# # --- main ---------------------------------------------------------------

# services = eligible_services.to_a
# staff    = staff_pool

# if services.empty?
#   puts "⚠️  No eligible services found. Nothing to seed."
#   puts "   Criteria: start_date within last 11 months, expire_date in future."
#   exit
# end

# if staff.empty?
#   puts "⚠️  No active staff found (users.active = true). Nothing to seed."
#   exit
# end

# puts "→ Eligible services: #{services.size}"
# puts "→ Active staff:      #{staff.size}"

# created_sessions   = 0
# created_adjustment = 0

# services.each_with_index do |svc, idx|
#   rng_seed = (svc.remote_purchase_id || svc.id).to_i
#   rng = Random.new(rng_seed)

#   remain = remaining_capacity(svc)
#   next if remain <= 0

#   # Decide how many sessions to create (bounded by capacity, up to 6 for brevity)
#   target_sessions = [remain, rng.rand(1..6)].min

#   client_id = svc.fliip_user_id
#   staff_index_start = idx % staff.size

#   # Time range for sessions
#   start_date = [svc.start_date || 11.months.ago.to_date, 11.months.ago.to_date].max
#   end_date   = [svc.expire_date || Time.zone.today, Time.zone.today].min

#   # Guard for invalid ranges
#   next if start_date > end_date

#   target_sessions.times do |n|
#     assignee = staff[(staff_index_start + n) % staff.size]

#     # Find a free 1h slot that doesn't collide for staff or client
#     tries = 0
#     at = nil
#     begin
#       at = pick_time_in_range(rng, start_date:, end_date:)
#       tries += 1
#     end while tries < 30 && (
#       slot_busy?(staff_busy[assignee.id], at) ||
#       slot_busy?(client_busy[client_id], at) ||
#       Session.exists?(user_id: assignee.id, occurred_at: at) ||
#       Session.exists?(fliip_user_id: client_id, occurred_at: at)
#     )

#     # Skip if no clean slot found
#     next if at.nil? || tries >= 30

#     attrs = {
#       user_id:         assignee.id,
#       created_by_id:   assignee.id,
#       fliip_user_id:   client_id,
#       fliip_service_id: svc.id,
#       occurred_at:     at
#     }

#     session = Session.find_or_create_by!(attrs) do |s|
#       s.duration     = 1.0
#       s.present      = rng.rand < 0.85
#       s.confirmed    = rng.rand < 0.80
#       s.confirmed_at = s.confirmed ? at + 5.minutes : nil
#       s.session_type = session_enum_name
#       s.note         = "[SEED] svc:#{svc.id} user:#{assignee.id} at:#{at.iso8601}"
#     end

#     if session.persisted?
#       created_sessions += 1 if session.previously_new_record?
#       mark_busy!(staff_busy[assignee.id], at)
#       mark_busy!(client_busy[client_id], at)
#     end
#   end

#   # Recompute remaining after sessions to see if adjustments fit safely
#   remain_after = remaining_capacity(svc)
#   next if remain_after <= 0

#   # Create up to 2 adjustments, ensuring they don't break capacity math.
#   # Each adjustment must be non-zero and in 0.5 increments.
#   adj_count = rng.rand(0..2)
#   adj_count.times do
#     # Determine allowed deltas without overrun/underrun
#     bonus, used_delta = totals_from_adjustments(svc)
#     used_sessions     = current_used_sessions(svc)
#     base_allowed      = allowed_capacity_for(svc)

#     total_cap   = base_allowed + bonus
#     total_used  = used_sessions + used_delta
#     room_up     = (total_cap - total_used).floor # how many more uses allowed
#     room_down   = total_used.floor               # how many we could “give back”

#     # Decide whether to add or subtract usage OR adjust bonus. Pick a safe option.
#     mode = [:used_up, :used_down, :bonus_up, :bonus_down].shuffle(random: rng).find do |m|
#       case m
#       when :used_up   then room_up   >= 1
#       when :used_down then room_down >= 1
#       when :bonus_up  then true
#       when :bonus_down then (bonus - 0.5) >= 0 # avoid negative bonus
#       end
#     end
#     next unless mode

#     # 0.5 or 1.0 step (non-zero)
#     step = rng.rand < 0.5 ? 0.5 : 1.0

#     paid_delta = 0.0
#     free_delta = 0.0
#     bonus_step = 0.0

#     case mode
#     when :used_up
#       if rng.rand < 0.5
#         paid_delta = step
#       else
#         free_delta = step
#       end
#     when :used_down
#       if rng.rand < 0.5
#         paid_delta = -step
#       else
#         free_delta = -step
#       end
#     when :bonus_up
#       bonus_step = step
#     when :bonus_down
#       bonus_step = -step
#     end

#     # Timestamp determinism per service + mode + step
#     stamp = Time.zone.parse("2024-01-01 10:00:00") + (rng_seed % 86_400)
#     key   = {
#       fliip_service_id: svc.id,
#       user_id:          staff[(staff_index_start) % staff.size].id,
#       created_at:       stamp
#     }

#     adj = ServiceUsageAdjustment.find_or_create_by!(key) do |a|
#       a.paid_used_delta  = paid_delta.zero? ? nil : paid_delta
#       a.free_used_delta  = free_delta.zero? ? nil : free_delta
#       a.bonus_sessions   = bonus_step.zero? ? nil : bonus_step
#       a.updated_at       = stamp
#     end

#     # If an adjustment with the same key already existed but had zeros (edge), ensure it’s non-zero
#     if adj.persisted? && adj.paid_used_delta.to_f.zero? && adj.free_used_delta.to_f.zero? && adj.bonus_sessions.to_f.zero?
#       adj.update!(
#         paid_used_delta: paid_delta.zero? ? nil : paid_delta,
#         free_used_delta: free_delta.zero? ? nil : free_delta,
#         bonus_sessions:  bonus_step.zero? ? nil : bonus_step
#       )
#     end

#     created_adjustment += 1 if adj.previously_new_record?
#   end
# end

# puts "✅ Done."
# puts "   → Sessions created (new this run):   #{created_sessions}"
# puts "   → Adjustments created (new this run): #{created_adjustment}"
