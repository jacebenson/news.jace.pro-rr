# frozen_string_literal: true

class CreateMvpAwards < ActiveRecord::Migration[8.0]
  def change
    create_table :mvp_awards do |t|
      t.references :participant, null: false, foreign_key: true
      t.integer :year, null: false
      t.string :award_type, null: false
      t.string :source_url

      t.timestamps
    end

    add_index :mvp_awards, :year
    add_index :mvp_awards, :award_type
    add_index :mvp_awards, [ :participant_id, :year, :award_type ], unique: true, name: 'index_mvp_awards_unique'
  end
end
