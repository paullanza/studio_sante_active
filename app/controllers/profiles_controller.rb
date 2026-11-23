# « Mon profil »: the signed-in staff member edits their own details and
# password. The record is always the current user; there is no id in the URL.
# Admins editing someone else still use UsersController#edit.
#
# The page has two forms, each on its own copy of the user, so one form's
# errors and unsaved values never show in the other.
class ProfilesController < ApplicationController
  layout "studio"

  before_action :authenticate_user!
  before_action :load_forms

  # GET /profil
  def show
    authorize @user
  end

  # PATCH /profil
  def update
    authorize @user

    if @user.update(permitted_attributes(@user))
      redirect_to profile_path, notice: "Profil mis à jour."
    else
      render :show, status: :unprocessable_content
    end
  end

  # PATCH /profil/password
  def update_password
    authorize @password_user, :update?

    if change_password
      # A new password rotates Devise's session salt; keep the person signed in.
      bypass_sign_in(@password_user)
      redirect_to profile_path, notice: "Mot de passe modifié."
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def load_forms
    @user = User.find(current_user.id)
    @password_user = User.find(current_user.id)
  end

  # Devise's update_with_password drops a blank new password and then
  # "succeeds" without changing anything, so a blank one is refused here.
  def change_password
    attributes = password_params

    if attributes[:password].blank?
      @password_user.errors.add(:password, :blank)
      return false
    end

    @password_user.update_with_password(attributes)
  ensure
    @password_user.clean_up_passwords
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
