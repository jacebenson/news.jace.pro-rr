class SessionsController < ApplicationController
  def new
    redirect_to items_path if logged_in?
  end

  def create
    user = User.find_by("LOWER(email) = ?", params[:email].downcase)

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to items_path, notice: "Welcome back, #{user.name || user.email}!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to items_path, notice: "You have been logged out"
  end
end
