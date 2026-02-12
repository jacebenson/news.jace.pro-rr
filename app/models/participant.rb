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

  def self.find_by_slug(slug)
    # Try exact match first, then parameterized match
    find_by(name: slug) || all.find { |p| p.slug == slug }
  end
end
