class CreateNewsItemTags < ActiveRecord::Migration[8.0]
  def change
    create_table :news_item_tags do |t|
      t.references :news_item, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
  end
end
