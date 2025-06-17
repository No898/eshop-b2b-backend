class CreateProductVariants < ActiveRecord::Migration[7.1]
  def change
    # Variant attributes (flavor, size, color, etc.)
    create_table :variant_attributes do |t|
      t.string :name, null: false, limit: 50        # "flavor", "size", "color"
      t.string :display_name, null: false, limit: 100 # "Příchuť", "Velikost", "Barva"
      t.text :description
      t.integer :sort_order, default: 0
      t.boolean :active, default: true, null: false

      t.timestamps

      t.index :name, unique: true
      t.index [:active, :sort_order]
    end

    # Variant attribute values (strawberry, large, red, etc.)
    create_table :variant_attribute_values do |t|
      t.references :variant_attribute, null: false, foreign_key: true
      t.string :value, null: false, limit: 100      # "strawberry", "large", "red"
      t.string :display_value, null: false, limit: 100 # "Jahoda", "Velká", "Červená"
      t.string :color_code, limit: 7                # "#FF0000" for visual representation
      t.text :description
      t.integer :sort_order, default: 0
      t.boolean :active, default: true, null: false

      t.timestamps

      t.index [:variant_attribute_id, :value], unique: true, name: 'idx_variant_attr_values_unique'
      t.index [:variant_attribute_id, :active, :sort_order], name: 'idx_variant_attr_values_active'
    end

    # Add variant support to products table
    add_column :products, :is_variant_parent, :boolean, default: false, null: false
    add_column :products, :parent_product_id, :bigint
    add_column :products, :variant_sku, :string, limit: 50
    add_column :products, :variant_sort_order, :integer, default: 0

    # Foreign key for parent-child relationship
    add_foreign_key :products, :products, column: :parent_product_id

    # Indexes for performance
    add_index :products, :is_variant_parent
    add_index :products, :parent_product_id
    add_index :products, :variant_sku, unique: true, where: "variant_sku IS NOT NULL"
    add_index :products, [:parent_product_id, :variant_sort_order], name: 'idx_products_variants_sorted'

    # Junction table for product variants and their attribute values
    create_table :product_variant_attributes do |t|
      t.references :product, null: false, foreign_key: true
      t.references :variant_attribute_value, null: false, foreign_key: true

      t.timestamps

      t.index [:product_id, :variant_attribute_value_id],
              unique: true,
              name: 'idx_product_variant_attrs_unique'
      t.index :variant_attribute_value_id, name: 'idx_product_variant_attrs_value'
    end

    # Add constraints
    add_check_constraint :products,
                        "(is_variant_parent = false AND parent_product_id IS NOT NULL) OR
                         (is_variant_parent = true AND parent_product_id IS NULL) OR
                         (is_variant_parent = false AND parent_product_id IS NULL)",
                        name: 'chk_products_variant_logic'

    add_check_constraint :variant_attributes,
                        "char_length(name) >= 2",
                        name: 'chk_variant_attributes_name_length'

    add_check_constraint :variant_attribute_values,
                        "char_length(value) >= 1",
                        name: 'chk_variant_attribute_values_length'
  end
end