class ApplicationController < ActionController::Base
  # THE FIFTH REQUIREMENT: Check user existence and active status before each request
  before_action :authenticate_and_validate_user!

  helper_method :current_user, :logged_in?

  private

  # Returns currently logged-in user from session
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  # Validates that user exists and is not blocked
  def authenticate_and_validate_user!
    if current_user.nil?
      session[:user_id] = nil
      redirect_to login_path
    elsif current_user.blocked?
      session[:user_id] = nil
      redirect_to login_path, alert: "Your account is blocked. Please contact support."
    end
  end
end