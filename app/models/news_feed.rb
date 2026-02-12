class NewsFeed < ApplicationRecord
  has_many :news_items, dependent: :nullify

  validates :title, presence: true

  scope :active, -> { where(active: true) }
  scope :not_dead, -> { where.not(status: "dead") }
  scope :fetchable, -> { active.not_dead }
end
