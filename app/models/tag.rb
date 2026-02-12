class Tag < ApplicationRecord
  has_many :news_item_tags, dependent: :destroy
  has_many :news_items, through: :news_item_tags

  validates :name, presence: true, uniqueness: true
end
