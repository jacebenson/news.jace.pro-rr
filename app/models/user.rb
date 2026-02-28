class User < ApplicationRecord
  has_secure_password

  has_many :knowledge_session_lists, dependent: :destroy
  has_many :saved_sessions, through: :knowledge_session_lists, source: :knowledge_session
  has_many :participants, dependent: :nullify

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  # Normalize email before validation
  before_validation :normalize_email

  # Send welcome email after creation
  after_create :send_welcome_email

  def admin?
    roles&.include?("admin")
  end

  def generate_password_reset_token!
    self.reset_token = SecureRandom.urlsafe_base64(32)
    self.reset_token_expires_at = 2.hours.from_now
    save!(validate: false)
  end

  def clear_password_reset_token!
    self.reset_token = nil
    self.reset_token_expires_at = nil
    save!(validate: false)
  end

  def password_reset_token_valid?
    reset_token.present? && reset_token_expires_at.present? && reset_token_expires_at > Time.current
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def send_welcome_email
    UserMailer.welcome_email(self).deliver_later
  end
end
