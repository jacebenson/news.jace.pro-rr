class CreateNewsItemParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :news_item_participants do |t|
      t.references :news_item, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true

      t.timestamps
    end
  end
end
