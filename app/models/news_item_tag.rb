class NewsItemTag < ApplicationRecord
  belongs_to :news_item
  belongs_to :tag
end
