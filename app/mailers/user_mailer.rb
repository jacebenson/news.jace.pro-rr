class UserMailer < ApplicationMailer
  default from: "news@jace.pro"

  def welcome_email(user)
    @user = user

    # Render templates
    html_content = render_to_string(template: "user_mailer/welcome_email", layout: "mailer", formats: [ :html ])
    text_content = render_to_string(template: "user_mailer/welcome_email", layout: "mailer", formats: [ :text ])

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

    # Render templates
    html_content = render_to_string(template: "user_mailer/password_reset", layout: "mailer", formats: [ :html ])
    text_content = render_to_string(template: "user_mailer/password_reset", layout: "mailer", formats: [ :text ])

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
