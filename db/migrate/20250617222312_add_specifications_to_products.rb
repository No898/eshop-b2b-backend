class AddSpecificationsToProducts < ActiveRecord::Migration[8.0]
  def change
    # BUSINESS LOGIC: Product specifications for B2B (sirupy, nádoby, atd.)
    add_column :products, :weight_value, :decimal, precision: 8, scale: 3, null: true
    add_column :products, :weight_unit, :string, limit: 10, null: true
    add_column :products, :ingredients, :text, null: true

    # PERFORMANCE: Index for filtering by weight/unit
    add_index :products, [:weight_value, :weight_unit], name: 'index_products_on_weight'

    # BUSINESS RULES: Check constraints for valid weight units and values
    execute <<~SQL
      ALTER TABLE products
      ADD CONSTRAINT check_products_weight_unit_valid
      CHECK (weight_unit IS NULL OR weight_unit IN ('kg', 'l', 'ml', 'g'));

      ALTER TABLE products
      ADD CONSTRAINT check_products_weight_value_positive
      CHECK (weight_value IS NULL OR weight_value > 0);

      -- Weight value and unit must be both present or both null
      ALTER TABLE products
      ADD CONSTRAINT check_products_weight_consistency
      CHECK ((weight_value IS NULL AND weight_unit IS NULL) OR
             (weight_value IS NOT NULL AND weight_unit IS NOT NULL));
    SQL
  end

  def down
    # ROLLBACK: Remove constraints first, then columns
    execute <<~SQL
      ALTER TABLE products DROP CONSTRAINT IF EXISTS check_products_weight_unit_valid;
      ALTER TABLE products DROP CONSTRAINT IF EXISTS check_products_weight_value_positive;
      ALTER TABLE products DROP CONSTRAINT IF EXISTS check_products_weight_consistency;
    SQL

    remove_index :products, name: 'index_products_on_weight'

    remove_column :products, :weight_value
    remove_column :products, :weight_unit
    remove_column :products, :ingredients
  end
end
