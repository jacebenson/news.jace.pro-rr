class Participant < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :company, optional: true

  has_many :news_item_participants, dependent: :destroy
  has_many :news_items, through: :news_item_participants

  has_many :knowledge_session_participants, dependent: :destroy
  has_many :knowledge_sessions, through: :knowledge_session_participants

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
end
