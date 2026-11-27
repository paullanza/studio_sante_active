require "rails_helper"

RSpec.describe UserPolicy, type: :policy do
  let!(:employee)      { create(:user) }
  let!(:colleague)     { create(:user) }
  let!(:manager)       { create(:user, :manager) }
  let!(:other_manager) { create(:user, :manager) }
  let!(:admin)         { create(:user, :admin) }
  let!(:other_admin)   { create(:user, :admin) }
  let!(:super_admin)   { create(:user, :super_admin) }

  def policy(actor, target)
    described_class.new(actor, target)
  end

  context "for an employee" do
    it "permits only viewing and editing themself, with no staff list" do
      expect(policy(employee, employee)).to permit_only_actions(:show, :edit, :update)
      expect(policy(employee, colleague)).to forbid_all_actions
      expect(policy(employee, manager)).to forbid_all_actions
    end
  end

  context "for a manager" do
    it "views everyone but the super admin and edits only themself" do
      expect(policy(manager, manager)).to permit_only_actions(:index, :show, :edit, :update)
      expect(policy(manager, other_manager)).to permit_only_actions(:index, :show)
      expect(policy(manager, admin)).to permit_only_actions(:index, :show)
      expect(policy(manager, super_admin)).to permit_only_actions(:index)
    end

    it "activates and deactivates employees only" do
      expect(policy(manager, employee)).to permit_only_actions(:index, :show, :activate, :deactivate)
    end
  end

  context "for an admin" do
    it "edits and manages employees and managers, but never makes admins" do
      expect(policy(admin, employee)).to permit_only_actions(:index, :show, :edit, :update, :update_role, :activate, :deactivate)
      expect(policy(admin, manager)).to permit_only_actions(:index, :show, :edit, :update, :update_role, :activate, :deactivate)
    end

    it "edits admins, themself included, without changing their role or status" do
      expect(policy(admin, other_admin)).to permit_only_actions(:index, :show, :edit, :update)
      expect(policy(admin, admin)).to permit_only_actions(:index, :show, :edit, :update)
    end

    it "cannot see or touch the super admin" do
      expect(policy(admin, super_admin)).to permit_only_actions(:index)
    end
  end

  context "for the super admin" do
    it "does everything to admins and managers, including role changes" do
      every_user_action = %i[show edit update update_role activate deactivate]

      expect(policy(super_admin, admin)).to permit_only_actions(:index, *every_user_action)
      expect(policy(super_admin, manager)).to permit_only_actions(:index, *every_user_action)
    end

    it "edits themself but never changes their own role or status" do
      expect(policy(super_admin, super_admin)).to permit_only_actions(:index, :show, :edit, :update)
    end
  end

  describe "#assignable_roles" do
    # Viewer × target → the roles the viewer may give, the current one left out.
    {
      %i[employee colleague]       => [],
      %i[manager employee]         => [],
      %i[manager other_manager]    => [],
      %i[admin employee]           => %w[manager],
      %i[admin manager]            => %w[employee],
      %i[admin other_admin]        => [],
      %i[admin admin]              => [],
      %i[admin super_admin]        => [],
      %i[super_admin employee]     => %w[manager admin],
      %i[super_admin manager]      => %w[employee admin],
      %i[super_admin admin]        => %w[employee manager],
      %i[super_admin super_admin]  => []
    }.each do |(viewer, target), roles|
      it "gives #{roles.inspect} to a #{viewer} looking at #{target}" do
        actors = { employee:, colleague:, manager:, other_manager:, admin:, other_admin:, super_admin: }

        expect(policy(actors[viewer], actors[target]).assignable_roles).to eq(roles)
      end
    end

    it "gives a guest nothing" do
      expect(policy(nil, employee).assignable_roles).to eq([])
    end
  end

  it "denies everything to a guest" do
    expect(policy(nil, employee)).to forbid_all_actions
  end

  describe "#permitted_attributes" do
    it "adds the email only on your own profile and never the password or role" do
      expect(policy(admin, admin)).to permit_attributes(:first_name, :last_name, :phone, :address, :birthday, :email)
      expect(policy(admin, employee)).to permit_attributes(:first_name, :last_name, :phone, :address, :birthday)
      expect(policy(admin, employee)).to forbid_attributes(:email, :password, :role, :active)
      expect(policy(employee, employee)).to forbid_attributes(:password, :role, :active)
    end
  end

  describe UserPolicy::Scope do
    def resolve(actor)
      described_class.new(actor, User).resolve
    end

    it "shows the super admin everyone" do
      expect(resolve(super_admin)).to match_array(User.all)
    end

    it "hides the super admin from admins and managers" do
      expect(resolve(admin)).to match_array(User.where.not(id: super_admin.id))
      expect(resolve(manager)).to match_array(User.where.not(id: super_admin.id))
    end

    it "shows employees only themselves, and guests nobody" do
      expect(resolve(employee)).to contain_exactly(employee)
      expect(resolve(nil)).to be_empty
    end
  end
end
