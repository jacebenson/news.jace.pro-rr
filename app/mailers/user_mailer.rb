class UserMailer < ApplicationMailer
  default from: "news@jace.pro"

  def welcome_email(user)
    @user = user

    html_content = welcome_email_html
    text_content = welcome_email_text

    send_via_mailgun_api(
      to: @user.email,
      subject: "Welcome to news.jace.pro!",
      html: html_content,
      text: text_content
    )
  end

  def password_reset(user)
    @user = user

    html_content = password_reset_html
    text_content = password_reset_text

    send_via_mailgun_api(
      to: @user.email,
      subject: "Password reset instructions",
      html: html_content,
      text: text_content
    )
  end

  private

  def welcome_email_html
    name = @user.name || @user.email
    <<-HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body>
  <h1>Welcome to news.jace.pro!</h1>
#{'  '}
  <p>Hi #{h(name)},</p>
#{'  '}
  <p>Thanks for signing up for news.jace.pro. Your account has been created successfully.</p>
#{'  '}
  <p>You can now:</p>
  <ul>
    <li>Browse the latest ServiceNow news</li>
    <li>Save Knowledge conference sessions to your personal list</li>
    <li>Manage your account settings</li>
  </ul>
#{'  '}
  <p><a href="https://news.jace.pro/i">Start browsing</a></p>
#{'  '}
  <p>Best regards,<br>The news.jace.pro team</p>
</body>
</html>
    HTML
  end

  def welcome_email_text
    name = @user.name || @user.email
    <<-TEXT
Welcome to news.jace.pro!

Hi #{name},

Thanks for signing up for news.jace.pro. Your account has been created successfully.

You can now:
- Browse the latest ServiceNow news
- Save Knowledge conference sessions to your personal list
- Manage your account settings

Start browsing: https://news.jace.pro/i

Best regards,
The news.jace.pro team
    TEXT
  end

  def password_reset_html
    name = @user.name || @user.email
    token = @user.reset_token
    <<-HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body>
  <h1>Password Reset Instructions</h1>
#{'  '}
  <p>Hi #{h(name)},</p>
#{'  '}
  <p>Someone requested a password reset for your news.jace.pro account. If this was you, click the link below to reset your password:</p>
#{'  '}
  <p><a href="https://news.jace.pro/reset-password?token=#{token}">Reset my password</a></p>
#{'  '}
  <p>This link will expire in 2 hours.</p>
#{'  '}
  <p>If you didn't request this, please ignore this email. Your password will remain unchanged.</p>
#{'  '}
  <p>Best regards,<br>The news.jace.pro team</p>
</body>
</html>
    HTML
  end

  def password_reset_text
    name = @user.name || @user.email
    token = @user.reset_token
    <<-TEXT
Password Reset Instructions

Hi #{name},

Someone requested a password reset for your news.jace.pro account. If this was you, click the link below to reset your password:

Reset my password: https://news.jace.pro/reset-password?token=#{token}

This link will expire in 2 hours.

If you didn't request this, please ignore this email. Your password will remain unchanged.

Best regards,
The news.jace.pro team
    TEXT
  end

  def h(text)
    ERB::Util.html_escape(text)
  end

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
