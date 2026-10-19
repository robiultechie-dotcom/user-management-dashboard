class RegistrationsController < ApplicationController
  # Allow non-authenticated users to view sign-up form and register
  skip_before_action :authenticate_and_validate_user!

  def new
    redirect_to root_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.status = "active"

    if @user.save
      # Automatically sign in immediately after registration
      @user.update_column(:last_login_at, Time.current)
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Account registered successfully! Welcome to The App."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end