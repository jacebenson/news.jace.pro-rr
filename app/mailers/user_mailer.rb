class UserMailer < ApplicationMailer
  default from: "news@jace.pro"

  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Welcome to news.jace.pro!")
  end

  def password_reset(user)
    @user = user
    mail(to: @user.email, subject: "Password reset instructions")
  end
end
