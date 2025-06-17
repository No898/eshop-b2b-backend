# 📍 Address Management System - Dokumentace

Kompletní dokumentace pro pokročilý adresní systém s českými B2B specifiky.

---

## 📋 Obsah
- [Přehled systému](#-přehled-systému)
- [Database Schema](#-database-schema)
- [Model & Validace](#-model--validace)
- [GraphQL API](#-graphql-api)
- [Business Logic](#-business-logic)
- [České B2B specifika](#-české-b2b-specifika)
- [Frontend integrace](#-frontend-integrace)
- [Testing](#-testing)

---

## 🏗 Přehled systému

### Účel
Address Management System umožňuje B2B klientům spravovat fakturační a doručovací adresy s plnou podporou českých firemních údajů (IČO, DIČ).

### Klíčové funkce
- ✅ **Dva typy adres**: Billing (fakturační) + Shipping (doručovací)
- ✅ **České B2B údaje**: IČO, DIČ s automatickou validací
- ✅ **Default adresy**: Jedna výchozí per typ per uživatel
- ✅ **Auto-formátování**: PSČ, DIČ se formátují automaticky
- ✅ **Thread-safe operations**: Bezpečná konkurenční práce
- ✅ **Comprehensive validation**: Business pravidla + formátová validace

---

## 🗄 Database Schema

### Migration
```ruby
# db/migrate/20250617222518_create_addresses.rb
class CreateAddresses < ActiveRecord::Migration[7.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true, index: true

      # Základní adresní údaje
      t.string :address_type, null: false, limit: 20
      t.string :street, null: false, limit: 200
      t.string :city, null: false, limit: 100
      t.string :postal_code, null: false, limit: 10
      t.string :country, null: false, limit: 2, default: 'CZ'

      # Firemní údaje (pouze pro billing)
      t.string :company_name, limit: 200
      t.string :company_vat_id, limit: 15        # DIČ
      t.string :company_registration_id, limit: 8 # IČO

      # Systémové
      t.boolean :is_default, null: false, default: false
      t.timestamps
    end

    # Indexes pro performance
    add_index :addresses, [:user_id, :address_type], name: 'idx_addresses_user_type'
    add_index :addresses, [:user_id, :is_default, :address_type],
              name: 'idx_addresses_user_default_type'

    # Constraints pro data integrity
    add_check_constraint :addresses, "address_type IN ('billing', 'shipping')",
                        name: 'chk_address_type'
    add_check_constraint :addresses, "length(postal_code) >= 5",
                        name: 'chk_postal_code_length'
    add_check_constraint :addresses, "length(company_registration_id) = 8 OR company_registration_id IS NULL",
                        name: 'chk_ico_length'
  end
end
```

### Schema struktura
```ruby
# db/schema.rb excerpt
create_table "addresses", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.string "address_type", limit: 20, null: false
  t.string "street", limit: 200, null: false
  t.string "city", limit: 100, null: false
  t.string "postal_code", limit: 10, null: false
  t.string "country", limit: 2, default: "CZ", null: false
  t.string "company_name", limit: 200
  t.string "company_vat_id", limit: 15
  t.string "company_registration_id", limit: 8
  t.boolean "is_default", default: false, null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["user_id", "address_type"], name: "idx_addresses_user_type"
  t.index ["user_id", "is_default", "address_type"], name: "idx_addresses_user_default_type"
  t.index ["user_id"], name: "index_addresses_on_user_id"
  t.check_constraint "address_type::text = ANY (ARRAY['billing'::character varying, 'shipping'::character varying]::text[])", name: "chk_address_type"
  t.check_constraint "company_registration_id IS NULL OR length(company_registration_id::text) = 8", name: "chk_ico_length"
  t.check_constraint "length(postal_code::text) >= 5", name: "chk_postal_code_length"
end
```

---

## 🏷 Model & Validace

### Address Model
```ruby
# app/models/address.rb
class Address < ApplicationRecord
  belongs_to :user

  # Enums
  enum address_type: { billing: 'billing', shipping: 'shipping' }

  # Validations
  validates :street, presence: true, length: { maximum: 200 }
  validates :city, presence: true, length: { maximum: 100 }
  validates :postal_code, presence: true, format: { with: /\A\d{3}\s?\d{2}\z/ }
  validates :country, presence: true, inclusion: { in: %w[CZ SK] }
  validates :address_type, presence: true, inclusion: { in: %w[billing shipping] }

  # Conditional validations pro billing adresy
  validates :company_registration_id, format: { with: /\A\d{8}\z/ },
            allow_blank: true, if: :billing?
  validates :company_vat_id, format: { with: /\ACZ\d{8,10}\z/ },
            allow_blank: true, if: :billing?

  # Business rules
  validates :company_name, :company_vat_id, :company_registration_id,
            absence: true, unless: :billing?

  # Callbacks
  before_validation :normalize_postal_code, :normalize_vat_id
  before_save :handle_default_address
  after_create :set_as_default_if_first

  # Scopes
  scope :billing, -> { where(address_type: 'billing') }
  scope :shipping, -> { where(address_type: 'shipping') }
  scope :defaults, -> { where(is_default: true) }

  private

  def normalize_postal_code
    return unless postal_code.present?

    # Remove spaces and format as "123 45"
    cleaned = postal_code.gsub(/\s+/, '')
    self.postal_code = "#{cleaned[0..2]} #{cleaned[3..4]}" if cleaned.length == 5
  end

  def normalize_vat_id
    return unless company_vat_id.present?

    # Ensure CZ prefix
    self.company_vat_id = "CZ#{company_vat_id}" unless company_vat_id.start_with?('CZ')
    self.company_vat_id = company_vat_id.upcase
  end

  def handle_default_address
    return unless is_default_changed? && is_default?

    # Unset other default addresses of the same type
    user.addresses.where(address_type: address_type, is_default: true)
        .where.not(id: id)
        .update_all(is_default: false)
  end

  def set_as_default_if_first
    return if user.addresses.where(address_type: address_type).count > 1

    update_column(:is_default, true)
  end
end
```

### User Model Extension
```ruby
# app/models/user.rb - přidané vztahy
class User < ApplicationRecord
  has_many :addresses, dependent: :destroy

  # Helper methods pro default adresy
  def default_billing_address
    addresses.billing.defaults.first
  end

  def default_shipping_address
    addresses.shipping.defaults.first || default_billing_address
  end

  def has_complete_billing_address?
    default_billing_address&.company_name.present?
  end
end
```

---

## 🔗 GraphQL API

### AddressType
```ruby
# app/graphql/types/address_type.rb
module Types
  class AddressType < Types::BaseObject
    field :id, ID, null: false
    field :address_type, String, null: false, description: "Typ adresy: billing nebo shipping"
    field :street, String, null: false, description: "Ulice a číslo popisné"
    field :city, String, null: false, description: "Město"
    field :postal_code, String, null: false, description: "PSČ ve formátu '123 45'"
    field :country, String, null: false, description: "Kód země (CZ, SK, atd.)"
    field :company_name, String, null: true, description: "Název firmy (pouze pro billing)"
    field :company_vat_id, String, null: true, description: "DIČ ve formátu CZ12345678"
    field :company_registration_id, String, null: true, description: "IČO - 8 číslic"
    field :is_default, Boolean, null: false, description: "Výchozí adresa pro daný typ"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
```

### Queries
```ruby
# app/graphql/types/user_type.rb - rozšíření
field :addresses, [Types::AddressType], null: false do
  argument :type, String, required: false
end

field :default_billing_address, Types::AddressType, null: true
field :default_shipping_address, Types::AddressType, null: true

def addresses(type: nil)
  scope = object.addresses
  scope = scope.where(address_type: type) if type.present?
  scope.order(:address_type, :created_at)
end

def default_billing_address
  object.default_billing_address
end

def default_shipping_address
  object.default_shipping_address
end
```

### Mutations
```ruby
# app/graphql/mutations/create_address.rb
module Mutations
  class CreateAddress < BaseMutation
    argument :address_type, String, required: true
    argument :street, String, required: true
    argument :city, String, required: true
    argument :postal_code, String, required: true
    argument :country, String, required: false
    argument :company_name, String, required: false
    argument :company_vat_id, String, required: false
    argument :company_registration_id, String, required: false
    argument :is_default, Boolean, required: false

    field :address, Types::AddressType, null: true
    field :errors, [String], null: false

    def resolve(**args)
      address = context[:current_user].addresses.build(args)

      if address.save
        { address: address, errors: [] }
      else
        { address: nil, errors: address.errors.full_messages }
      end
    end
  end
end
```

---

## 🧠 Business Logic

### Adresní pravidla
1. **Billing Address**
   - MŮŽE obsahovat firemní údaje (company_name, company_vat_id, company_registration_id)
   - Je POVINNÁ pro B2B klienty
   - Používá se jako fallback pro shipping pokud není shipping definována

2. **Shipping Address**
   - NESMÍ obsahovat firemní údaje
   - Je VOLITELNÁ
   - Pokud neexistuje, použije se billing address

3. **Default Logic**
   - Každý user může mít max 1 default billing a 1 default shipping
   - První adresa daného typu se automaticky stává default
   - Nastavení nové default automaticky zruší předchozí

### Thread Safety
Systém je navržen jako thread-safe:
- `handle_default_address` callback zajišťuje atomickou operaci
- Database constraints zabraňují nevalidním stavům
- Transakce zajišťují konsistenci

---

## 🇨🇿 České B2B specifika

### IČO (Company Registration ID)
- **Formát**: Přesně 8 číslic
- **Validace**: `/\A\d{8}\z/`
- **Použití**: Identifikace firmy v českém obchodním rejstříku
- **Povinnost**: Volitelné, ale doporučené pro B2B

### DIČ (VAT ID)
- **Formát**: CZ + 8-10 číslic
- **Validace**: `/\ACZ\d{8,10}\z/`
- **Auto-formátování**: Automaticky přidá "CZ" prefix
- **Použití**: Pro daňové účely a fakturaci
- **Povinnost**: Povinné pro firmy s obratem nad limit

### PSČ (Postal Code)
- **Formát**: "123 45" (3+2 číslice s mezerou)
- **Validace**: `/\A\d{3}\s?\d{2}\z/`
- **Auto-formátování**: Automaticky přidá mezeru
- **Příklady**: "110 00" (Praha), "602 00" (Brno)

### Podporované země
- **CZ** (Česká republika) - default
- **SK** (Slovensko) - pro slovenské B2B klienty

---

## 💻 Frontend integrace

### React komponenty
Systém poskytuje ready-to-use React komponenty:
- `AddressForm` - formulář pro vytváření/editaci adres
- `AddressList` - seznam všech adres uživatele
- `AddressCard` - zobrazení jednotlivé adresy

### GraphQL operace
```graphql
# Vytvoření adresy
mutation CreateAddress($input: CreateAddressInput!) {
  createAddress(input: $input) {
    address { id addressType street city }
    errors
  }
}

# Načtení adres
query GetUserAddresses {
  currentUser {
    addresses { id addressType street city isDefault }
  }
}
```

### UX Best practices
- Automatické formátování při psaní
- Inline validace IČO/DIČ
- Visual feedback pro default adresy
- Conditional fields pro business údaje
- Responsive design pro mobile

---

## 🧪 Testing

### Model testy
```ruby
# spec/models/address_spec.rb
RSpec.describe Address, type: :model do
  describe 'validations' do
    it 'validates postal code format' do
      address = build(:address, postal_code: '12345')
      expect(address).to be_valid

      address.postal_code = '123 45'
      expect(address).to be_valid

      address.postal_code = '1234'
      expect(address).not_to be_valid
    end

    it 'validates IČO format for billing addresses' do
      address = build(:address, :billing, company_registration_id: '12345678')
      expect(address).to be_valid

      address.company_registration_id = '123456789'
      expect(address).not_to be_valid
    end
  end

  describe 'default address handling' do
    it 'sets first address as default' do
      user = create(:user)
      address = create(:address, user: user, address_type: 'billing')

      expect(address.reload).to be_is_default
    end

    it 'unsets previous default when setting new default' do
      user = create(:user)
      first = create(:address, user: user, address_type: 'billing')
      second = create(:address, user: user, address_type: 'billing', is_default: true)

      expect(first.reload).not_to be_is_default
      expect(second.reload).to be_is_default
    end
  end
end
```

### GraphQL testy
```ruby
# spec/graphql/mutations/create_address_spec.rb
RSpec.describe Mutations::CreateAddress, type: :graphql do
  it 'creates valid billing address with company data' do
    user = create(:user)

    result = execute_graphql(
      mutation: CREATE_ADDRESS_MUTATION,
      variables: {
        input: {
          addressType: 'billing',
          street: 'Václavské náměstí 123',
          city: 'Praha',
          postalCode: '11000',
          companyName: 'Lootea s.r.o.',
          companyRegistrationId: '12345678',
          companyVatId: 'CZ12345678'
        }
      },
      current_user: user
    )

    expect(result['data']['createAddress']['address']).to include(
      'street' => 'Václavské náměstí 123',
      'city' => 'Praha',
      'postalCode' => '110 00',  # auto-formatted
      'companyName' => 'Lootea s.r.o.',
      'isDefault' => true
    )
  end
end
```

---

## 🚀 Deployment notes

### Environment variables
Nejsou potřeba žádné speciální environment variables.

### Database migrations
```bash
rails db:migrate
```

### Seeds (volitelné)
```ruby
# db/seeds.rb - příklad testovacích adres
if Rails.env.development?
  user = User.first

  user.addresses.create!(
    address_type: 'billing',
    street: 'Václavské náměstí 123',
    city: 'Praha',
    postal_code: '110 00',
    company_name: 'Lootea s.r.o.',
    company_registration_id: '12345678',
    company_vat_id: 'CZ12345678'
  )
end
```

---

## 📚 Related Documentation
- [FRONTEND_GUIDE.md](./FRONTEND_GUIDE.md) - Frontend implementace
- [GRAPHQL_GUIDE.md](./GRAPHQL_GUIDE.md) - GraphQL API reference
- [INVENTORY_SYSTEM.md](./INVENTORY_SYSTEM.md) - Inventory management

---

*Dokumentace aktualizována: `date +"%Y-%m-%d"`*