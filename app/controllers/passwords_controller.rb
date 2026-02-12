class PasswordsController < ApplicationController
  def new
  end

  def create
    # TODO: Implement password reset
    flash[:notice] = "If an account with that email exists, we sent password reset instructions."
    redirect_to login_path
  end

  def edit
  end

  def update
    # TODO: Implement password reset
    flash[:alert] = "Password reset not yet implemented"
    redirect_to login_path
  end
end
