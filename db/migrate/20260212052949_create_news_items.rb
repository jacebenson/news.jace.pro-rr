class CreateNewsItems < ActiveRecord::Migration[8.0]
  def change
    create_table :news_items do |t|
      t.string :item_type, default: 'article'
      t.boolean :active, default: true
      t.string :state, default: 'new'
      t.string :title
      t.text :body
      t.string :url
      t.string :image_url
      t.string :duration
      t.datetime :published_at
      t.datetime :event_start
      t.datetime :event_end
      t.string :event_location
      t.string :ad_url
      t.string :call_to_action
      t.references :news_feed, null: true, foreign_key: true

      t.timestamps
    end
    add_index :news_items, :url, unique: true
    add_index :news_items, [ :title, :published_at ]
  end
end
