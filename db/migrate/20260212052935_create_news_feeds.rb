class CreateNewsFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :news_feeds do |t|
      t.string :title
      t.boolean :active, default: true
      t.string :status, default: 'active'
      t.text :notes
      t.string :image_url
      t.string :url
      t.string :default_author
      t.string :feed_type, default: 'rss'
      t.string :fetch_url
      t.datetime :last_successful_fetch
      t.text :last_error
      t.integer :error_count, default: 0

      t.timestamps
    end
    add_index :news_feeds, :title
    add_index :news_feeds, :active
    add_index :news_feeds, :feed_type
    add_index :news_feeds, :status
  end
end
