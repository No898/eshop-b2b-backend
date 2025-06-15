class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.integer :price_cents, null: false
      t.string :currency, default: "CZK", null: false
      t.boolean :available, default: true, null: false

      t.timestamps
    end
    
    add_index :products, :available
  end
end
