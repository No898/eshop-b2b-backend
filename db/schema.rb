# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_19_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "address_type", limit: 20, null: false
    t.string "company_name", limit: 255
    t.string "company_vat_id", limit: 20
    t.string "company_registration_id", limit: 20
    t.string "street", limit: 255, null: false
    t.string "city", limit: 100, null: false
    t.string "postal_code", limit: 10, null: false
    t.string "country", limit: 2, default: "CZ", null: false
    t.string "phone", limit: 20
    t.text "notes"
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["postal_code"], name: "index_addresses_on_postal_code"
    t.index ["user_id", "address_type", "is_default"], name: "index_addresses_unique_default_per_type", unique: true, where: "(is_default = true)"
    t.index ["user_id", "address_type"], name: "index_addresses_on_user_and_type"
    t.index ["user_id", "is_default"], name: "index_addresses_on_user_and_default"
    t.index ["user_id"], name: "index_addresses_on_user_id"
    t.check_constraint "address_type::text = ANY (ARRAY['billing'::character varying, 'shipping'::character varying]::text[])", name: "check_addresses_type_valid"
    t.check_constraint "company_registration_id IS NULL OR company_registration_id::text ~ '^[0-9]{8}$'::text", name: "check_addresses_ico_format"
    t.check_constraint "company_vat_id IS NULL OR company_vat_id::text ~ '^(CZ|SK)[0-9]{8,10}$'::text", name: "check_addresses_dic_format"
    t.check_constraint "country::text = ANY (ARRAY['CZ'::character varying, 'SK'::character varying]::text[])", name: "check_addresses_country_valid"
    t.check_constraint "postal_code::text ~ '^[0-9]{3}\\s?[0-9]{2}$'::text", name: "check_addresses_postal_code_format"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_id"], name: "index_order_items_on_order_id_and_product_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "total_cents", null: false
    t.string "currency", default: "CZK", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_id"
    t.string "payment_url"
    t.integer "payment_status", default: 0
    t.index ["payment_id"], name: "index_orders_on_payment_id"
    t.index ["payment_status"], name: "index_orders_on_payment_status"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id", "created_at"], name: "index_orders_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "product_price_tiers", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "tier_name", limit: 50, null: false
    t.integer "min_quantity", null: false
    t.integer "max_quantity"
    t.integer "price_cents", null: false
    t.string "currency", limit: 3, default: "CZK", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "active", "priority"], name: "idx_price_tiers_product_active_priority"
    t.index ["product_id", "min_quantity"], name: "idx_price_tiers_product_min_qty"
    t.index ["product_id", "tier_name"], name: "idx_unique_product_tier_name", unique: true
    t.index ["product_id"], name: "index_product_price_tiers_on_product_id"
    t.index ["tier_name"], name: "idx_price_tiers_tier_name"
    t.check_constraint "max_quantity IS NULL OR max_quantity >= min_quantity", name: "chk_max_quantity_valid"
    t.check_constraint "min_quantity > 0", name: "chk_min_quantity_positive"
    t.check_constraint "price_cents > 0", name: "chk_price_cents_positive"
    t.check_constraint "tier_name::text = ANY (ARRAY['1ks'::character varying, '1bal'::character varying, '10bal'::character varying, 'custom'::character varying]::text[])", name: "chk_tier_name_valid"
  end

  create_table "product_variant_attributes", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "variant_attribute_value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "variant_attribute_value_id"], name: "idx_product_variant_attrs_unique", unique: true
    t.index ["product_id"], name: "index_product_variant_attributes_on_product_id"
    t.index ["variant_attribute_value_id"], name: "idx_product_variant_attrs_value"
    t.index ["variant_attribute_value_id"], name: "index_product_variant_attributes_on_variant_attribute_value_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "price_cents", null: false
    t.string "currency", default: "CZK", null: false
    t.boolean "available", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "quantity", default: 0, null: false
    t.integer "low_stock_threshold", default: 10, null: false
    t.decimal "weight_value", precision: 8, scale: 3
    t.string "weight_unit", limit: 10
    t.text "ingredients"
    t.boolean "is_variant_parent", default: false, null: false
    t.bigint "parent_product_id"
    t.string "variant_sku", limit: 50
    t.integer "variant_sort_order", default: 0
    t.index ["available"], name: "index_products_on_available"
    t.index ["is_variant_parent"], name: "index_products_on_is_variant_parent"
    t.index ["parent_product_id", "variant_sort_order"], name: "idx_products_variants_sorted"
    t.index ["parent_product_id"], name: "index_products_on_parent_product_id"
    t.index ["quantity", "available"], name: "index_products_on_quantity_and_available"
    t.index ["quantity"], name: "index_products_on_quantity"
    t.index ["variant_sku"], name: "index_products_on_variant_sku", unique: true, where: "(variant_sku IS NOT NULL)"
    t.index ["weight_value", "weight_unit"], name: "index_products_on_weight"
    t.check_constraint "is_variant_parent = false AND parent_product_id IS NOT NULL OR is_variant_parent = true AND parent_product_id IS NULL OR is_variant_parent = false AND parent_product_id IS NULL", name: "chk_products_variant_logic"
    t.check_constraint "low_stock_threshold > 0", name: "check_products_low_stock_threshold_positive"
    t.check_constraint "quantity >= 0", name: "check_products_quantity_non_negative"
    t.check_constraint "weight_unit IS NULL OR (weight_unit::text = ANY (ARRAY['kg'::character varying, 'l'::character varying, 'ml'::character varying, 'g'::character varying]::text[]))", name: "check_products_weight_unit_valid"
    t.check_constraint "weight_value IS NULL AND weight_unit IS NULL OR weight_value IS NOT NULL AND weight_unit IS NOT NULL", name: "check_products_weight_consistency"
    t.check_constraint "weight_value IS NULL OR weight_value > 0::numeric", name: "check_products_weight_value_positive"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role"
    t.string "company_name"
    t.string "vat_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "variant_attribute_values", force: :cascade do |t|
    t.bigint "variant_attribute_id", null: false
    t.string "value", limit: 100, null: false
    t.string "display_value", limit: 100, null: false
    t.string "color_code", limit: 7
    t.text "description"
    t.integer "sort_order", default: 0
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["variant_attribute_id", "active", "sort_order"], name: "idx_variant_attr_values_active"
    t.index ["variant_attribute_id", "value"], name: "idx_variant_attr_values_unique", unique: true
    t.index ["variant_attribute_id"], name: "index_variant_attribute_values_on_variant_attribute_id"
    t.check_constraint "char_length(value::text) >= 1", name: "chk_variant_attribute_values_length"
  end

  create_table "variant_attributes", force: :cascade do |t|
    t.string "name", limit: 50, null: false
    t.string "display_name", limit: 100, null: false
    t.text "description"
    t.integer "sort_order", default: 0
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "sort_order"], name: "index_variant_attributes_on_active_and_sort_order"
    t.index ["name"], name: "index_variant_attributes_on_name", unique: true
    t.check_constraint "char_length(name::text) >= 2", name: "chk_variant_attributes_name_length"
  end

  add_foreign_key "addresses", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "users"
  add_foreign_key "product_price_tiers", "products"
  add_foreign_key "product_variant_attributes", "products"
  add_foreign_key "product_variant_attributes", "variant_attribute_values"
  add_foreign_key "products", "products", column: "parent_product_id"
  add_foreign_key "variant_attribute_values", "variant_attributes"
end
