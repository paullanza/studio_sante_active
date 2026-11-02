# frozen_string_literal: true

class ApplicationPolicy
  # Role predicates for the signed-in user, shared by policies and scopes.
  # admin? and super_admin? stay separate so the two roles can diverge in
  # one place; use admin_or_above? when both should pass.
  module RoleHelpers
    private

    def employee?
      user&.employee?
    end

    def manager?
      user&.manager?
    end

    def admin?
      user&.admin?
    end

    def super_admin?
      user&.super_admin?
    end

    def admin_or_above?
      admin? || super_admin?
    end

    def manager_or_above?
      manager? || admin_or_above?
    end
  end

  include RoleHelpers

  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    include RoleHelpers

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
