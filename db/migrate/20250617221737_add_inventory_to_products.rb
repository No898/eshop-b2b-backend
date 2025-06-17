class AddInventoryToProducts < ActiveRecord::Migration[8.0]
  def change
    # BUSINESS LOGIC: Add inventory tracking with proper constraints and defaults
    add_column :products, :quantity, :integer, null: false, default: 0
    add_column :products, :low_stock_threshold, :integer, null: false, default: 10

    # PERFORMANCE: Add database indexes for frequently queried columns
    add_index :products, :quantity, name: 'index_products_on_quantity'
    add_index :products, [:quantity, :available], name: 'index_products_on_quantity_and_available'

    # BUSINESS RULES: Add check constraints for data integrity
    execute <<~SQL
      ALTER TABLE products
      ADD CONSTRAINT check_products_quantity_non_negative
      CHECK (quantity >= 0);

      ALTER TABLE products
      ADD CONSTRAINT check_products_low_stock_threshold_positive
      CHECK (low_stock_threshold > 0);
    SQL
  end

  def down
    # ROLLBACK: Remove constraints first, then columns
    execute <<~SQL
      ALTER TABLE products DROP CONSTRAINT IF EXISTS check_products_quantity_non_negative;
      ALTER TABLE products DROP CONSTRAINT IF EXISTS check_products_low_stock_threshold_positive;
    SQL

    remove_index :products, name: 'index_products_on_quantity'
    remove_index :products, name: 'index_products_on_quantity_and_available'

    remove_column :products, :quantity
    remove_column :products, :low_stock_threshold
  end
end
