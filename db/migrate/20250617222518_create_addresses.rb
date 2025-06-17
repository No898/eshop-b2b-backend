class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address_type, null: false, limit: 20
      t.string :company_name, limit: 255
      t.string :company_vat_id, limit: 20          # DIČ
      t.string :company_registration_id, limit: 20 # IČO
      t.string :street, null: false, limit: 255
      t.string :city, null: false, limit: 100
      t.string :postal_code, null: false, limit: 10
      t.string :country, null: false, default: 'CZ', limit: 2
      t.string :phone, limit: 20
      t.text :notes
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    # PERFORMANCE: Indexes for frequent queries
    add_index :addresses, [:user_id, :address_type], name: 'index_addresses_on_user_and_type'
    add_index :addresses, [:user_id, :is_default], name: 'index_addresses_on_user_and_default'
    add_index :addresses, :postal_code, name: 'index_addresses_on_postal_code'

    # BUSINESS RULES: Check constraints for data integrity
    execute <<~SQL
      ALTER TABLE addresses
      ADD CONSTRAINT check_addresses_type_valid
      CHECK (address_type IN ('billing', 'shipping'));

      ALTER TABLE addresses
      ADD CONSTRAINT check_addresses_country_valid
      CHECK (country IN ('CZ', 'SK'));

      ALTER TABLE addresses
      ADD CONSTRAINT check_addresses_postal_code_format
      CHECK (postal_code ~ '^[0-9]{3}\\s?[0-9]{2}$');

      -- Czech IČO format: 8 digits
      ALTER TABLE addresses
      ADD CONSTRAINT check_addresses_ico_format
      CHECK (company_registration_id IS NULL OR company_registration_id ~ '^[0-9]{8}$');

      -- Czech/Slovak DIČ format: CZ12345678 or SK12345678
      ALTER TABLE addresses
      ADD CONSTRAINT check_addresses_dic_format
      CHECK (company_vat_id IS NULL OR company_vat_id ~ '^(CZ|SK)[0-9]{8,10}$');
    SQL

    # BUSINESS RULE: Only one default address per type per user
    add_index :addresses, [:user_id, :address_type, :is_default],
              unique: true,
              where: "is_default = true",
              name: 'index_addresses_unique_default_per_type'
  end

  def down
    # ROLLBACK: Remove constraints first, then table
    execute <<~SQL
      ALTER TABLE addresses DROP CONSTRAINT IF EXISTS check_addresses_type_valid;
      ALTER TABLE addresses DROP CONSTRAINT IF EXISTS check_addresses_country_valid;
      ALTER TABLE addresses DROP CONSTRAINT IF EXISTS check_addresses_postal_code_format;
      ALTER TABLE addresses DROP CONSTRAINT IF EXISTS check_addresses_ico_format;
      ALTER TABLE addresses DROP CONSTRAINT IF EXISTS check_addresses_dic_format;
    SQL

    drop_table :addresses
  end
end
