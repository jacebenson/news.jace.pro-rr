class CreateServicenowStoreApps < ActiveRecord::Migration[8.0]
  def change
    create_table :servicenow_store_apps do |t|
      t.string :source_app_id
      t.string :title
      t.string :tagline
      t.text :store_description
      t.string :company_name
      t.string :company_logo
      t.string :logo
      t.string :app_type
      t.string :app_sub_type
      t.string :version
      t.text :versions_data
      t.integer :purchase_count
      t.integer :review_count
      t.integer :table_count
      t.text :key_features
      t.text :business_challenge
      t.text :system_requirements
      t.text :supporting_media
      t.text :support_links
      t.text :support_contacts
      t.text :purchase_trend
      t.string :display_price
      t.string :landing_page
      t.boolean :allow_for_existing_customers
      t.boolean :allow_for_non_customers
      t.boolean :allow_on_customer_subprod
      t.boolean :allow_on_developer_instance
      t.boolean :allow_on_servicenow_instance
      t.boolean :allow_trial
      t.boolean :allow_without_license
      t.datetime :last_fetched_at
      t.datetime :published_at

      t.timestamps
    end
    add_index :servicenow_store_apps, :source_app_id, unique: true
  end
end
