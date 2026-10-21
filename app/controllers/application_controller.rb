class ApplicationController < ActionController::Base
  # THE FIFTH REQUIREMENT: Check user existence and active status before each request
  before_action :authenticate_and_validate_user!

  helper_method :current_user, :logged_in?

  private

  # Strictly retrieves current user from valid session with no fallback
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = if session[:user_id].present?
                      User.find_by(id: session[:user_id])
                    end
  end

  def logged_in?
    current_user.present?
  end

  # Blocks any unauthenticated or blocked user and forces immediate login redirect
  def authenticate_and_validate_user!
    if current_user.nil?
      reset_session
      redirect_to login_path and return
    elsif current_user.blocked?
      reset_session
      redirect_to login_path, alert: "Your account is blocked. Please contact support." and return
    end
  end
end