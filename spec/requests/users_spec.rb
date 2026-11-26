require "rails_helper"

RSpec.describe "Users", type: :request do
  let!(:employee)    { create(:user) }
  let!(:colleague)   { create(:user) }
  let!(:manager)     { create(:user, :manager) }
  let!(:other_manager) { create(:user, :manager) }
  let!(:admin)       { create(:user, :admin) }
  let!(:other_admin) { create(:user, :admin) }
  let!(:super_admin) { create(:user, :super_admin) }

  def everyone
    { employee:, colleague:, manager:, other_manager:, admin:, other_admin:, super_admin: }
  end

  def profile_params(**overrides)
    { user: { first_name: "Nouveau", email: "nouveau-#{SecureRandom.hex(3)}@example.com",
              password: "changed123", role: "super_admin", active: "0" }.merge(overrides) }
  end

  context "when signed out" do
    it "redirects to sign-in" do
      get user_path(employee)
      expect(response).to redirect_to(new_user_session_path)
      patch deactivate_user_path(employee)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /users/:id" do
    {
      employee: %i[employee],
      manager: %i[employee colleague manager other_manager admin other_admin],
      admin: %i[employee colleague manager other_manager admin other_admin],
      super_admin: %i[employee colleague manager other_manager admin other_admin super_admin]
    }.each do |viewer, visible|
      it "shows a #{viewer} only the profiles they may see" do
        sign_in everyone[viewer]

        everyone.each do |name, user|
          get user_path(user)
          expect(response.status == 200).to eq(visible.include?(name)), "#{viewer} viewing #{name}"
        end
      end
    end

    it "sends a refused viewer back with an alert" do
      sign_in employee
      get user_path(colleague)

      expect(response).to redirect_to(authenticated_root_path)
      expect(flash[:alert]).to eq("Non autorisé·e.")
    end
  end

  describe "GET /personnel" do
    def listed_ids
      Nokogiri::HTML(response.body).css("table.from-tablet tbody tr a").map { |a| a["href"] }
    end

    %i[manager admin super_admin].each do |viewer|
      it "opens for #{viewer}" do
        sign_in everyone[viewer]
        get users_path

        expect(response).to have_http_status(:ok)
      end
    end

    it "sends an employee back with the alert" do
      sign_in employee
      get users_path

      expect(response).to redirect_to(authenticated_root_path)
    end

    it "lists everyone but the super admin to a manager, active by default" do
      colleague.update!(active: false)
      sign_in manager

      get users_path
      # The list is only visible in the markup.
      expect(listed_ids).to include(user_path(employee), user_path(other_manager), user_path(admin))
      expect(listed_ids).not_to include(user_path(super_admin), user_path(colleague))

      get users_path(statut: "inactifs")
      expect(listed_ids).to eq([ user_path(colleague) ])

      get users_path(statut: "tous", role: "manager")
      expect(listed_ids).to contain_exactly(user_path(manager), user_path(other_manager))
    end

    it "counts unconfirmed séances and consultations and services worked on" do
      service = create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 10, free_sessions: 2))
      create(:session, fliip_service: service, user: employee)
      create(:session, fliip_service: service, user: employee, occurred_at: 2.days.ago).update_columns(confirmed: true)
      create(:consultation, user: employee)
      create(:service_usage_adjustment, user: employee)
      sign_in admin

      get users_path(role: "employee")

      row = Nokogiri::HTML(response.body).css("table.from-tablet tbody tr").find { |tr| tr.at_css("a")["href"] == user_path(employee) }
      expect(row.css("td.numeric").map { |td| td.text.strip }).to eq(%w[1 1 2])
    end
  end

  describe "a staff member's page" do
    before { travel_to Time.zone.local(2026, 11, 26, 12, 0) }

    let(:service) { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 5)) }

    def seance(time, **attrs)
      create(:session, fliip_service: service, user: employee, **attrs).tap { |s| s.update_columns(occurred_at: time) }
    end

    def stats
      Nokogiri::HTML(response.body).css("#activity_totals_user_#{employee.id} .stat").to_h do |stat|
        [ stat.at_css(".stat__label").text.strip, stat.at_css(".stat__value").text.strip ]
      end
    end

    it "totals the period's séances by outcome and in hours, and its consultations" do
      seance(Time.zone.local(2026, 11, 23, 9, 0))
      seance(Time.zone.local(2026, 11, 23, 10, 0), duration: 0.5)
      seance(Time.zone.local(2026, 11, 24, 9, 0), present: false)
      seance(Time.zone.local(2026, 11, 25, 9, 0)).update_columns(session_type: "paid", present: false, confirmed: true)
      create(:consultation, user: employee, occurred_at: Time.zone.local(2026, 11, 24, 15, 0), present: false)
      sign_in manager

      get user_path(employee)

      expect(stats).to include("Présent·e" => "2", "Absence" => "1", "-24h" => "1", "heures de séance" => "3,5 h",
                               "séances confirmées" => "1 / 4", "consultations, absent·e" => "1")
    end

    it "keeps each period to Sunday through Saturday" do
      seance(Time.zone.local(2026, 11, 21, 23, 0))
      seance(Time.zone.local(2026, 11, 22, 0, 30))
      sign_in admin

      get user_path(employee)
      expect(stats["Présent·e"]).to eq("1")

      get user_path(employee, periode: "2026-11-08")
      expect(stats["Présent·e"]).to eq("1")
    end

    it "lists the services they work on in the Services tab" do
      seance(Time.zone.local(2026, 11, 23, 9, 0))
      sign_in employee

      get user_path(employee, tab: "services")

      expect(response.body).to include(fliip_service_path(service))
    end

    it "redraws the totals after a séance is edited on the page" do
      record = seance(Time.zone.local(2026, 11, 23, 9, 0))
      sign_in admin

      patch session_path(record), params: { context: "personnel", trainer_id: employee.id,
                                            session: { note: "x", present: "0", duration: "1.0", date: "2026-11-23", time: "09:00" } },
                                  headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.body).to include(%(target="activity_totals_user_#{employee.id}"))
    end

    it "never draws another staff member's totals for an employee" do
      record = seance(Time.zone.local(2026, 11, 23, 9, 0))
      sign_in employee

      patch session_path(record), params: { context: "personnel", trainer_id: manager.id,
                                            session: { note: "x", present: "1", duration: "1.0", date: "2026-11-23", time: "09:00" } },
                                  headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.body).not_to include("activity_totals_user_#{manager.id}")
      expect(response.body).to include("activity_totals_user_#{employee.id}")
    end

    it "redraws the totals after a consultation is deleted on the page" do
      consultation = create(:consultation, user: employee, occurred_at: Time.zone.local(2026, 11, 24, 15, 0))
      sign_in admin

      delete consultation_path(consultation), params: { context: "personnel" }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.body).to include(%(target="activity_totals_user_#{employee.id}"))
    end
  end

  describe "editing profiles" do
    {
      employee: %i[employee],
      manager: %i[manager],
      admin: %i[employee colleague manager other_manager admin other_admin],
      super_admin: %i[employee colleague manager other_manager admin other_admin super_admin]
    }.each do |editor, editable|
      it "lets a #{editor} edit only the profiles they may" do
        sign_in everyone[editor]

        everyone.each do |name, user|
          get edit_user_path(user)
          expect(response.status == 200).to eq(editable.include?(name)), "#{editor} editing #{name}"

          patch user_path(user), params: profile_params
          expect(user.reload.first_name == "Nouveau").to eq(editable.include?(name)), "#{editor} updating #{name}"
          user.update_columns(first_name: "Avant")
        end
      end
    end

    it "changes the email only on your own profile" do
      sign_in admin

      patch user_path(employee), params: profile_params(email: "autre@example.com")
      expect(employee.reload.email).not_to eq("autre@example.com")

      patch user_path(admin), params: profile_params(email: "moi@example.com")
      expect(admin.reload.email).to eq("moi@example.com")
    end

    it "never changes the password, role or active flag" do
      sign_in super_admin

      patch user_path(employee), params: profile_params

      employee.reload
      expect(employee.valid_password?("changed123")).to be false
      expect(employee).to be_employee
      expect(employee).to be_active
    end

    it "keeps the old alert when a visible profile cannot be edited" do
      sign_in manager
      get edit_user_path(employee)

      expect(response).to redirect_to(user_path(employee))
      expect(flash[:alert]).to eq("Not authorized.")
    end

    it "re-renders the profile with errors when a field is invalid" do
      sign_in employee
      patch user_path(employee), params: { user: { first_name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "role changes" do
    it "lets admins demote a manager and promote an employee" do
      sign_in admin

      patch make_employee_user_path(manager)
      expect(manager.reload).to be_employee
      patch make_manager_user_path(employee)
      expect(employee.reload).to be_manager
    end

    it "stops admins from changing any admin, themself included, or making admins" do
      sign_in admin

      patch make_manager_user_path(other_admin)
      patch make_manager_user_path(admin)
      patch make_admin_user_path(manager)

      expect(other_admin.reload).to be_admin
      expect(admin.reload).to be_admin
      expect(manager.reload).to be_manager
    end

    it "lets the super admin demote an admin and promote a manager to admin" do
      sign_in super_admin

      patch make_manager_user_path(admin)
      expect(admin.reload).to be_manager
      patch make_admin_user_path(other_manager)
      expect(other_admin.reload).to be_admin
      expect(other_manager.reload).to be_admin
    end

    it "keeps each target rule and its message" do
      sign_in super_admin

      patch make_admin_user_path(employee)
      expect(flash[:alert]).to eq("Only managers can be promoted to admin.")
      patch make_employee_user_path(employee)
      expect(flash[:alert]).to eq("Only managers can be demoted to employee.")
      patch make_manager_user_path(manager)
      expect(flash[:alert]).to eq("This change isn’t allowed.")
    end

    it "never changes the super admin" do
      sign_in super_admin

      patch make_manager_user_path(super_admin)

      expect(super_admin.reload).to be_super_admin
      expect(flash[:alert]).to eq("You can't change a Super Admin.")
    end

    it "is refused to managers and employees" do
      [manager, employee].each do |user|
        sign_in user
        patch make_manager_user_path(colleague)
        expect(colleague.reload).to be_employee
      end
    end
  end

  describe "activation" do
    {
      employee: [],
      manager: %i[employee colleague],
      admin: %i[employee colleague manager other_manager],
      super_admin: %i[employee colleague manager other_manager admin other_admin]
    }.each do |actor, allowed|
      it "lets a #{actor} deactivate and reactivate only the users they may" do
        sign_in everyone[actor]

        everyone.each do |name, user|
          patch deactivate_user_path(user)
          expect(user.reload.active).to eq(!allowed.include?(name)), "#{actor} deactivating #{name}"

          user.update_columns(active: false)
          patch activate_user_path(user)
          expect(user.reload.active).to eq(allowed.include?(name)), "#{actor} activating #{name}"
          user.update_columns(active: true)
        end
      end
    end

    it "keeps the old alerts" do
      sign_in manager

      patch deactivate_user_path(other_manager)
      expect(flash[:alert]).to eq("Not authorized to deactivate this user.")
      patch activate_user_path(other_manager)
      expect(flash[:alert]).to eq("Not authorized to activate this user.")
    end
  end
end
