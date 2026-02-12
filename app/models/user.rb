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

  def admin?
    roles&.include?("admin")
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
