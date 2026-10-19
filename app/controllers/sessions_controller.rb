class SessionsController < ApplicationController
  # Allow non-authenticated users to access login actions
  skip_before_action :authenticate_and_validate_user!, except: [:destroy]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    user = User.find_by(email: params[:email]&.strip&.downcase)

    if user&.authenticate(params[:password])
      # Prevent blocked users from signing in
      if user.blocked?
        flash.now[:alert] = "This account is blocked and cannot log in."
        render :new, status: :unauthorized
      else
        user.update_column(:last_login_at, Time.current)
        session[:user_id] = user.id
        redirect_to root_path, notice: "Signed in successfully."
      end
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unauthorized
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "You have been logged out."
  end
end