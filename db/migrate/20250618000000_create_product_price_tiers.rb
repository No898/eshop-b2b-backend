class CreateProductPriceTiers < ActiveRecord::Migration[7.0]
  def change
    create_table :product_price_tiers do |t|
      t.references :product, null: false, foreign_key: true, index: true

      # Pricing tier definition
      t.string :tier_name, null: false, limit: 50          # "1ks", "1bal", "10bal"
      t.integer :min_quantity, null: false                 # Minimální množství pro tuto cenu
      t.integer :max_quantity, null: true                  # Maximální množství (null = neomezeno)
      t.integer :price_cents, null: false                  # Cena v haléřích pro tuto úroveň
      t.string :currency, null: false, default: 'CZK', limit: 3

      # Metadata
      t.text :description                                   # "Cena za balení 12 kusů"
      t.boolean :active, null: false, default: true        # Možnost deaktivace tier
      t.integer :priority, null: false, default: 0         # Pro řazení (0 = nejvyšší priorita)

      t.timestamps
    end

    # Indexes pro performance
    add_index :product_price_tiers, [:product_id, :min_quantity],
              name: 'idx_price_tiers_product_min_qty'
    add_index :product_price_tiers, [:product_id, :active, :priority],
              name: 'idx_price_tiers_product_active_priority'
    add_index :product_price_tiers, [:tier_name], name: 'idx_price_tiers_tier_name'

    # Constraints pro data integrity
    add_check_constraint :product_price_tiers,
                        "min_quantity > 0",
                        name: 'chk_min_quantity_positive'

    add_check_constraint :product_price_tiers,
                        "max_quantity IS NULL OR max_quantity >= min_quantity",
                        name: 'chk_max_quantity_valid'

    add_check_constraint :product_price_tiers,
                        "price_cents > 0",
                        name: 'chk_price_cents_positive'

    add_check_constraint :product_price_tiers,
                        "tier_name IN ('1ks', '1bal', '10bal', 'custom')",
                        name: 'chk_tier_name_valid'

    # Unique constraint - jeden tier name per product
    add_index :product_price_tiers, [:product_id, :tier_name],
              unique: true, name: 'idx_unique_product_tier_name'
  end
end