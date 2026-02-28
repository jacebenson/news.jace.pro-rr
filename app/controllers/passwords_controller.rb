class PasswordsController < ApplicationController
  def new
  end

  def create
    @user = User.find_by(email: params[:email].to_s.downcase.strip)

    if @user
      @user.generate_password_reset_token!
      UserMailer.password_reset(@user).deliver_later
    end

    # Always show the same message to prevent email enumeration attacks
    flash[:notice] = "If an account with that email exists, we sent password reset instructions."
    redirect_to login_path
  end

  def edit
    @user = User.find_by(reset_token: params[:token])

    if @user.nil? || !@user.password_reset_token_valid?
      flash[:alert] = "Invalid or expired password reset token. Please request a new one."
      redirect_to forgot_password_path
    end
  end

  def update
    @user = User.find_by(reset_token: params[:token])

    if @user.nil? || !@user.password_reset_token_valid?
      flash[:alert] = "Invalid or expired password reset token. Please request a new one."
      redirect_to forgot_password_path
      return
    end

    if params[:password].blank?
      flash.now[:alert] = "Password cannot be blank"
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Passwords do not match"
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      @user.clear_password_reset_token!
      flash[:notice] = "Your password has been reset successfully. Please login with your new password."
      redirect_to login_path
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
