# frozen_string_literal: true

class CreateStartupFounders < ActiveRecord::Migration[8.0]
  def change
    create_table :startup_founders do |t|
      t.references :participant, null: false, foreign_key: true
      t.string :company_name, null: false
      t.string :source_url

      t.timestamps
    end

    add_index :startup_founders, :company_name
    add_index :startup_founders, [ :participant_id, :company_name ], unique: true, name: 'index_startup_founders_unique'
  end
end
