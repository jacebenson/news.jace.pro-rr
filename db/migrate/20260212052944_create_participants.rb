class CreateParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :participants do |t|
      t.string :name
      t.text :alias
      t.string :company_name
      t.string :title
      t.text :bio
      t.string :image_url
      t.string :linkedin_url
      t.references :user, null: true, foreign_key: true
      t.references :company, null: true, foreign_key: true

      t.timestamps
    end
    add_index :participants, :name, unique: true
  end
end
