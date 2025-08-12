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

puts "🎉 Seeding complete!"
puts "   → Users:        #{User.count}"
puts "   → SignupCodes:  #{SignupCode.count}"
