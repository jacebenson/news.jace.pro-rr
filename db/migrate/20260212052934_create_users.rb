class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :name
      t.string :link
      t.string :roles
      t.string :reset_token
      t.datetime :reset_token_expires_at

    end
    add_index :users, :email, unique: true
  end
end
