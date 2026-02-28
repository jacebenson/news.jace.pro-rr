module Admin
  class EmailTestsController < BaseController
    def new
    end

    def create
      recipient = params[:recipient]
      subject = params[:subject]
      body = params[:body]

      if recipient.blank? || subject.blank? || body.blank?
        flash[:alert] = "All fields are required"
        render :new, status: :unprocessable_entity
        return
      end

      begin
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
            text: body
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

      redirect_to new_admin_email_test_path
    end
  end
end
