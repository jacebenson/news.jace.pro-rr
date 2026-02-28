# frozen_string_literal: true

class CreateSnappCards < ActiveRecord::Migration[8.0]
  def change
    create_table :snapp_cards do |t|
      t.references :participant, null: false, foreign_key: true
      t.string :edition, null: false
      t.string :card_name, null: false

      t.timestamps
    end

    add_index :snapp_cards, :edition
    add_index :snapp_cards, [ :participant_id, :edition, :card_name ], unique: true, name: 'index_snapp_cards_unique'
  end
end
