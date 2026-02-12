class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name
      t.text :alias, default: '[]'
      t.boolean :active, default: true
      t.boolean :is_customer, default: false
      t.boolean :is_partner, default: false
      t.string :website
      t.string :image_url
      t.text :notes
      t.string :city
      t.string :state
      t.string :country
      t.string :build_level
      t.string :consulting_level
      t.string :reseller_level
      t.string :service_provider_level
      t.string :partner_level
      t.string :servicenow_url
      t.string :rss_feed_url
      t.string :servicenow_page_url
      t.text :products, default: '[]'
      t.text :services, default: '[]'
      t.datetime :last_fetched_at
      t.datetime :last_sitemap_check
      t.boolean :has_sitemap
      t.datetime :last_found_in_partner_list
      t.text :locked_fields, default: '[]'

      t.timestamps
    end
    add_index :companies, :name, unique: true
    add_index :companies, :is_customer
    add_index :companies, :is_partner
    add_index :companies, :active
  end
end
