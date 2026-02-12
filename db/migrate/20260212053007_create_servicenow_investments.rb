class CreateServicenowInvestments < ActiveRecord::Migration[8.0]
  def change
    create_table :servicenow_investments do |t|
      t.string :investment_type
      t.text :content
      t.text :summary
      t.string :url
      t.string :amount
      t.string :currency
      t.datetime :date
      t.text :people
      t.string :company_name

      t.timestamps
    end
  end
end
