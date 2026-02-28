class UserMailer < ApplicationMailer
  default from: "news@jace.pro"

  # Ensure all URLs in emails use the correct host
  default_url_options[:host] = "news.jace.pro"
  default_url_options[:protocol] = "https"

  def welcome_email(user)
    @user = user

    # Render templates with URL helpers using correct host
    html_content = render_email_content("welcome_email", :html)
    text_content = render_email_content("welcome_email", :text)

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

    # Render templates with URL helpers using correct host
    html_content = render_email_content("password_reset", :html)
    text_content = render_email_content("password_reset", :text)

    # Send via Mailgun HTTP API
    send_via_mailgun_api(
      to: @user.email,
      subject: "Password reset instructions",
      html: html_content,
      text: text_content
    )
  end

  private

  def render_email_content(template_name, format)
    # Use ActionView to render the template with proper context
    view = ActionView::Base.new(ActionMailer::Base.view_paths, {}, self)
    view.class_eval do
      include ApplicationHelper
      include Rails.application.routes.url_helpers

      def default_url_options
        { host: "news.jace.pro", protocol: "https" }
      end
    end

    view.instance_variable_set(:@user, @user)

    # Find and render the layout
    layout = view.lookup_context.find_layout("mailer", [ format ])

    # Find and render the template content
    template = view.lookup_context.find_template("user_mailer/#{template_name}", [], false, [], formats: [ format ])
    content = template.render(view, {})

    # Wrap in layout if found
    if layout
      view.instance_variable_set(:@content_for_layout, content)
      layout.render(view, {})
    else
      content
    end
  rescue => e
    Rails.logger.error("Error rendering email template #{template_name}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    "Email content rendering failed"
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
