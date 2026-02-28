module Admin
  class EmailTestsController < BaseController
    AVAILABLE_TEMPLATES = {
      "welcome_email" => "Welcome Email",
      "password_reset" => "Password Reset"
    }.freeze

    def new
      @template = params[:template] || "custom"
      @recipient = params[:recipient] || current_user.email

      if AVAILABLE_TEMPLATES.key?(@template)
        @preview = build_template_preview(@template)
      end
    end

    def create
      recipient = params[:recipient]
      template = params[:template]

      if recipient.blank?
        flash[:alert] = "Recipient email is required"
        redirect_to new_admin_email_test_path(template: template)
        return
      end

      begin
        # Build email content based on template selection
        if AVAILABLE_TEMPLATES.key?(template)
          email_data = build_template_email(template)
          subject = email_data[:subject]
          html_body = email_data[:html]
          text_body = email_data[:text]
        else
          # Custom email
          subject = params[:subject]
          text_body = params[:body]
          html_body = "<pre>#{ERB::Util.html_escape(text_body)}</pre>"

          if subject.blank? || text_body.blank?
            flash[:alert] = "Subject and body are required for custom emails"
            redirect_to new_admin_email_test_path(template: template)
            return
          end
        end

        response = HTTParty.post(
          "https://api.mailgun.net/v3/news.jace.pro/messages",
          basic_auth: {
            username: "api",
            password: ENV["MAILGUN_API_KEY"]
          },
          body: {
            from: "news@jace.pro",
            to: recipient,
            subject: subject,
            html: html_body,
            text: text_body
          }
        )

        if response.success?
          flash[:notice] = "Email sent successfully! Message ID: #{response.parsed_response['id']}"
        else
          flash[:alert] = "Failed to send email: #{response.body}"
        end
      rescue => e
        flash[:alert] = "Error sending email: #{e.message}"
      end

      redirect_to new_admin_email_test_path(template: template)
    end

    private

    def build_template_preview(template)
      sample_user = User.new(
        email: "preview@example.com",
        name: "Preview User",
        reset_token: "sample_token_12345"
      )

      mailer = UserMailer.new
      mailer.instance_variable_set(:@user, sample_user)

      case template
      when "welcome_email"
        {
          subject: "Welcome to news.jace.pro!",
          html: mailer.send(:welcome_email_html),
          text: mailer.send(:welcome_email_text)
        }
      when "password_reset"
        {
          subject: "Password reset instructions",
          html: mailer.send(:password_reset_html),
          text: mailer.send(:password_reset_text)
        }
      end
    end

    def build_template_email(template)
      # Use current user as sample, but override email with actual recipient
      sample_user = User.new(
        email: params[:recipient],
        name: current_user.name || current_user.email,
        reset_token: SecureRandom.urlsafe_base64(32)
      )

      mailer = UserMailer.new
      mailer.instance_variable_set(:@user, sample_user)

      case template
      when "welcome_email"
        {
          subject: "Welcome to news.jace.pro!",
          html: mailer.send(:welcome_email_html),
          text: mailer.send(:welcome_email_text)
        }
      when "password_reset"
        {
          subject: "Password reset instructions",
          html: mailer.send(:password_reset_html),
          text: mailer.send(:password_reset_text)
        }
      end
    end
  end
end
