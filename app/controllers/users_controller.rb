class UsersController < ApplicationController
  # THE THIRD REQUIREMENT: Sorted by last login time (newest first)
  def index
    @users = User.order(last_login_at: :desc, created_at: :desc)
  end

  # Block selected users
  def block
    selected_users = User.where(id: params[:user_ids])
    
    if selected_users.any?
      selected_users.update_all(status: "blocked")
      flash[:notice] = "Selected user(s) have been blocked."
    else
      flash[:alert] = "No users selected."
    end

    handle_self_action_redirect
  end

  # Unblock selected users
  def unblock
    selected_users = User.where(id: params[:user_ids])

    if selected_users.any?
      selected_users.update_all(status: "active")
      flash[:notice] = "Selected user(s) have been unblocked."
    else
      flash[:alert] = "No users selected."
    end

    redirect_to root_path
  end

  # Hard delete selected users
  def destroy_multiple
    selected_users = User.where(id: params[:user_ids])

    if selected_users.any?
      selected_users.destroy_all
      flash[:notice] = "Selected user(s) have been permanently deleted."
    else
      flash[:alert] = "No users selected."
    end

    handle_self_action_redirect
  end

  private

  # If current user blocked or deleted themselves, logout immediately
  def handle_self_action_redirect
    if current_user.nil? || current_user.blocked?
      session[:user_id] = nil
      redirect_to login_path, alert: "Your account is no longer active. You have been signed out."
    else
      redirect_to root_path
    end
  end
end