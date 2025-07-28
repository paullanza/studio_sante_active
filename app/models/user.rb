class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles
  enum role: { employee: 0, manager: 1, admin: 2 }

  # Default new users to :employee
  after_initialize do
    self.role ||= :employee
  end

  # Validations
  validates :first_name, :last_name, :phone, :address, :birthday, presence: true
end
