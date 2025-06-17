class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address_type
      t.string :company_name
      t.string :street
      t.string :city
      t.string :postal_code
      t.string :country
      t.string :phone
      t.text :notes
      t.boolean :is_default

      t.timestamps
    end
  end
end
