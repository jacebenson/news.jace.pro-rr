class UserMailer < ApplicationMailer
  default from: "news@jace.pro"

  def welcome_email(user)
    @user = user

    # Use ActionController renderer to render templates
    html_content = ApplicationController.render(
      template: "user_mailer/welcome_email",
      layout: "mailer",
      assigns: { user: @user },
      formats: [ :html ]
    )

    text_content = ApplicationController.render(
      template: "user_mailer/welcome_email",
      layout: "mailer",
      assigns: { user: @user },
      formats: [ :text ]
    )

    # Send via Mailgun HTTP API
    send_via_mailgun_api(
      to: @user.email,
      subject: "Welcome to news.jace.pro!",
      html: html_content,
      text: text_content
    )
  end

  def password_reset(user)
    @user = user

    # Use ActionController renderer to render templates
    html_content = ApplicationController.render(
      template: "user_mailer/password_reset",
      layout: "mailer",
      assigns: { user: @user },
      formats: [ :html ]
    )

    text_content = ApplicationController.render(
      template: "user_mailer/password_reset",
      layout: "mailer",
      assigns: { user: @user },
      formats: [ :text ]
    )

    # Send via Mailgun HTTP API
    send_via_mailgun_api(
      to: @user.email,
      subject: "Password reset instructions",
      html: html_content,
      text: text_content
    )
  end

  private

  def send_via_mailgun_api(to:, subject:, html:, text:)
    response = HTTParty.post(
      "https://api.mailgun.net/v3/news.jace.pro/messages",
      basic_auth: {
        username: "api",
        password: ENV["MAILGUN_API_KEY"]
      },
      body: {
        from: "news@jace.pro",
        to: to,
        subject: subject,
        html: html,
        text: text
      }
    )

    unless response.success?
      raise "Mailgun API error: #{response.body}"
    end

    response
  end
end
