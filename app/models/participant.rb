class Participant < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :company, optional: true

  has_many :news_item_participants, dependent: :destroy
  has_many :news_items, through: :news_item_participants

  has_many :knowledge_session_participants, dependent: :destroy
  has_many :knowledge_sessions, through: :knowledge_session_participants

  has_many :mvp_awards, dependent: :destroy
  has_many :snapp_cards, dependent: :destroy
  has_many :startup_founders, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def slug
    name.parameterize
  end

  # Find participant by slug (parameterized name)
  # Uses SQL LOWER() to do case-insensitive search without loading all records
  def self.find_by_slug(slug)
    return nil if slug.blank?

    # Try exact name match first
    result = find_by(name: slug)
    return result if result

    # Convert slug back to potential name formats and search
    # e.g., "john-doe" could be "John Doe", "john doe", "JOHN DOE", etc.
    normalized_slug = slug.to_s.downcase.gsub(/[^a-z0-9]/, "")

    # Search using SQL - compare normalized versions
    # This avoids loading all records into memory
    where("LOWER(REPLACE(REPLACE(REPLACE(name, ' ', ''), '-', ''), '_', '')) = ?", normalized_slug).first
  end

  # Scopes for filtering participants with specific data
  scope :with_mvp_awards, -> { joins(:mvp_awards).distinct }
  scope :with_snapp_cards, -> { joins(:snapp_cards).distinct }
  scope :with_startup_founders, -> { joins(:startup_founders).distinct }

  # Helper methods to check if participant has specific data
  def has_mvp_awards?
    mvp_awards.exists?
  end

  def has_snapp_cards?
    snapp_cards.exists?
  end

  def is_startup_founder?
    startup_founders.exists?
  end

  # Get all MVP award years
  def mvp_years
    mvp_awards.pluck(:year).uniq.sort.reverse
  end

  # Get MVP awards grouped by year
  def mvp_awards_by_year
    mvp_awards.recent_first.group_by(&:year)
  end

  # Count of MVP awards
  def mvp_award_count
    mvp_awards.count
  end

  # Get unique award types
  def mvp_award_types
    mvp_awards.pluck(:award_type).uniq
  end
end
