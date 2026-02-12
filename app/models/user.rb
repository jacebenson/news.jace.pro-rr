class User < ApplicationRecord
  has_secure_password

  has_many :knowledge_session_lists, dependent: :destroy
  has_many :saved_sessions, through: :knowledge_session_lists, source: :knowledge_session
  has_many :participants, dependent: :nullify

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  def admin?
    roles&.include?("admin")
  end
end
