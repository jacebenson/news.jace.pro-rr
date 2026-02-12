class NewsItem < ApplicationRecord
  belongs_to :news_feed, optional: true

  has_many :news_item_participants, dependent: :destroy
  has_many :participants, through: :news_item_participants

  has_many :news_item_tags, dependent: :destroy
  has_many :tags, through: :news_item_tags

  validates :url, presence: true, uniqueness: true
  validates :title, presence: true

  scope :active, -> { where(active: true) }
  scope :recent, -> { order(published_at: :desc) }
  scope :articles, -> { where(item_type: "article") }
  scope :videos, -> { where(item_type: "video") }
  scope :audio, -> { where(item_type: "audio") }

  def video?
    item_type == "video"
  end

  def article?
    item_type == "article"
  end
end
