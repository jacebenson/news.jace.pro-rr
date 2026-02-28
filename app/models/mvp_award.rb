class MvpAward < ApplicationRecord
  belongs_to :participant

  validates :year, presence: true, numericality: { only_integer: true }
  validates :award_type, presence: true
  validates :participant_id, uniqueness: { scope: [ :year, :award_type ], message: "already has this award for this year" }

  scope :by_year, ->(year) { where(year: year) }
  scope :by_award_type, ->(type) { where(award_type: type) }
  scope :recent_first, -> { order(year: :desc, created_at: :desc) }
  scope :oldest_first, -> { order(year: :asc, created_at: :asc) }

  # Award type constants
  MEMBER_OF_THE_MONTH = "Member of the Month"
  COMMUNITY_MVP = "Community MVP"
  DEVELOPER_MVP = "Developer MVP"
  RISING_STAR = "Rising Star"
  MOST_VALUABLE_PROFESSIONAL = "Most Valuable Professional"

  AWARD_TYPES = [
    MEMBER_OF_THE_MONTH,
    COMMUNITY_MVP,
    DEVELOPER_MVP,
    RISING_STAR,
    MOST_VALUABLE_PROFESSIONAL
  ].freeze

  def self.award_types
    AWARD_TYPES
  end

  def display_name
    "#{award_type} #{year}"
  end

  def badge_color
    case award_type
    when MOST_VALUABLE_PROFESSIONAL
      "bg-purple-100 text-purple-800"
    when DEVELOPER_MVP
      "bg-blue-100 text-blue-800"
    when COMMUNITY_MVP
      "bg-green-100 text-green-800"
    when RISING_STAR
      "bg-yellow-100 text-yellow-800"
    when MEMBER_OF_THE_MONTH
      "bg-gray-100 text-gray-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
