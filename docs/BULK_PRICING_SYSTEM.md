# 🏷️ Bulk Pricing System - Dokumentace

Komplexní systém množstevních slev pro B2B e-commerce s českými specifiky.

---

## 📋 Obsah
- [Přehled systému](#-přehled-systému)
- [Business logika](#-business-logika)
- [Database schema](#-database-schema)
- [Model implementation](#-model-implementation)
- [GraphQL API](#-graphql-api)
- [Frontend integrace](#-frontend-integrace)
- [Testing](#-testing)
- [Příklady použití](#-příklady-použití)

---

## 🏗 Přehled systému

### Účel
Bulk Pricing System umožňuje nastavit různé ceny produktů podle objednaného množství - typické pro B2B trh s cenami "1ks", "1bal", "10bal".

### Klíčové funkce
- ✅ **Flexibilní cenové úrovně** - 1ks, 1bal, 10bal, custom
- ✅ **Dynamické ceny** - automatický výpočet nejlepší ceny pro dané množství
- ✅ **Thread-safe operace** - bezpečné paralelní použití
- ✅ **B2B orientace** - množstevní slevy až 20%
- ✅ **GraphQL integrace** - real-time price calculation
- ✅ **Czech localization** - česká terminologie a měna

---

## 💼 Business logika

### Cenové úrovně (Tier Names)
```ruby
# Standardní B2B tiers
'1ks'   # Jednotlivé kusy (retail cena)
'1bal'  # Jedno balení (typicky 10-12 kusů)
'10bal' # Kartón/paleta (120+ kusů)
'custom' # Vlastní množstevní slevy
```

### Pravidla cenových úrovní
1. **Min/Max Quantity** - každý tier má rozsah množství
2. **Priority System** - při překryvu vybere se levnější
3. **Active Status** - možnost dočasně deaktivovat tier
4. **Automatic Calculation** - frontend dostane nejlepší cenu automaticky

### Typické cenové struktury
```
Popping Pearls (3.2kg balení):
├── 1ks:   1-11 kusů   → 250 CZK/ks
├── 1bal:  12-119 kusů → 220 CZK/ks (-12%)
└── 10bal: 120+ kusů   → 200 CZK/ks (-20%)

Bubble Tea Slamky (100ks balení):
├── 1ks:   1-9 balení  → 80 CZK/bal
├── 1bal:  10-49 bal   → 72 CZK/bal (-10%)
└── 10bal: 50+ bal     → 64 CZK/bal (-20%)
```

---

## 🗄 Database Schema

### ProductPriceTiers Table
```sql
CREATE TABLE product_price_tiers (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id),

  -- Tier definition
  tier_name VARCHAR(50) NOT NULL CHECK (tier_name IN ('1ks', '1bal', '10bal', 'custom')),
  min_quantity INTEGER NOT NULL CHECK (min_quantity > 0),
  max_quantity INTEGER CHECK (max_quantity IS NULL OR max_quantity >= min_quantity),
  price_cents INTEGER NOT NULL CHECK (price_cents > 0),
  currency VARCHAR(3) NOT NULL DEFAULT 'CZK',

  -- Metadata
  description TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  priority INTEGER NOT NULL DEFAULT 0,

  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  -- Indexes
  UNIQUE(product_id, tier_name)
);

-- Performance indexes
CREATE INDEX idx_price_tiers_product_min_qty ON product_price_tiers(product_id, min_quantity);
CREATE INDEX idx_price_tiers_product_active_priority ON product_price_tiers(product_id, active, priority);
```

### Migration
```ruby
# db/migrate/20250618000000_create_product_price_tiers.rb
class CreateProductPriceTiers < ActiveRecord::Migration[7.0]
  def change
    create_table :product_price_tiers do |t|
      t.references :product, null: false, foreign_key: true, index: true

      # Pricing tier definition
      t.string :tier_name, null: false, limit: 50
      t.integer :min_quantity, null: false
      t.integer :max_quantity, null: true
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: 'CZK', limit: 3

      # Metadata
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 0

      t.timestamps
    end

    # Database constraints
    add_check_constraint :product_price_tiers, "min_quantity > 0", name: 'chk_min_quantity_positive'
    add_check_constraint :product_price_tiers, "max_quantity IS NULL OR max_quantity >= min_quantity", name: 'chk_max_quantity_valid'
    add_check_constraint :product_price_tiers, "price_cents > 0", name: 'chk_price_cents_positive'
    add_check_constraint :product_price_tiers, "tier_name IN ('1ks', '1bal', '10bal', 'custom')", name: 'chk_tier_name_valid'

    # Unique constraint
    add_index :product_price_tiers, [:product_id, :tier_name], unique: true, name: 'idx_unique_product_tier_name'
  end
end
```

---

## 🏷 Model Implementation

### ProductPriceTier Model
```ruby
# app/models/product_price_tier.rb
class ProductPriceTier < ApplicationRecord
  belongs_to :product

  # Enums for tier names
  enum tier_name: {
    '1ks' => '1ks',        # Jednotlivé kusy
    '1bal' => '1bal',      # Jedno balení
    '10bal' => '10bal',    # Kartón/paleta
    'custom' => 'custom'   # Vlastní slevy
  }

  # Validations
  validates :tier_name, presence: true, inclusion: { in: tier_names.keys }
  validates :min_quantity, presence: true, numericality: { greater_than: 0 }
  validates :max_quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[CZK EUR] }

  # Business validation
  validate :max_quantity_greater_than_min
  validate :unique_tier_per_product

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_quantity, ->(qty) { where('min_quantity <= ? AND (max_quantity IS NULL OR max_quantity >= ?)', qty, qty) }
  scope :ordered_by_priority, -> { order(:priority, :min_quantity) }

  # Business methods
  def price
    price_cents / 100.0
  end

  def formatted_price
    "#{price} #{currency}"
  end

  def applies_to_quantity?(quantity)
    quantity >= min_quantity && (max_quantity.nil? || quantity <= max_quantity)
  end

  def savings_compared_to_base_price
    return 0 unless product.price_cents > price_cents
    ((product.price_cents - price_cents) / product.price_cents.to_f * 100).round(2)
  end

  def quantity_range_description
    if max_quantity.nil?
      "#{min_quantity}+ kusů"
    elsif min_quantity == max_quantity
      "#{min_quantity} kusů"
    else
      "#{min_quantity}-#{max_quantity} kusů"
    end
  end

  # Class method pro najití nejlepší ceny
  def self.best_price_for_quantity(product_id, quantity)
    where(product_id: product_id)
      .active
      .for_quantity(quantity)
      .order(:price_cents)
      .first
  end
end
```

### Product Model Extension
```ruby
# app/models/product.rb - přidané metody
class Product < ApplicationRecord
  has_many :price_tiers, class_name: 'ProductPriceTier', dependent: :destroy

  # BULK PRICING METHODS
  def price_for_quantity(quantity)
    tier = best_price_tier_for_quantity(quantity)
    return price if tier.nil?
    tier.price
  end

  def price_cents_for_quantity(quantity)
    tier = best_price_tier_for_quantity(quantity)
    return price_cents if tier.nil?
    tier.price_cents
  end

  def best_price_tier_for_quantity(quantity)
    price_tiers
      .active
      .for_quantity(quantity)
      .order(:price_cents, :priority)
      .first
  end

  def available_price_tiers
    price_tiers.active.ordered_by_priority
  end

  def has_bulk_pricing?
    price_tiers.active.exists?
  end

  def bulk_savings_for_quantity(quantity)
    tier = best_price_tier_for_quantity(quantity)
    return 0 unless tier

    base_total = price_cents * quantity
    tier_total = tier.price_cents * quantity

    return 0 unless base_total > tier_total
    ((base_total - tier_total) / base_total.to_f * 100).round(2)
  end
end
```

---

## 🔗 GraphQL API

### ProductPriceTierType
```ruby
# app/graphql/types/product_price_tier_type.rb
module Types
  class ProductPriceTierType < Types::BaseObject
    field :id, ID, null: false
    field :tier_name, String, null: false, description: "Název cenové úrovně (1ks, 1bal, 10bal)"
    field :min_quantity, Integer, null: false, description: "Minimální množství"
    field :max_quantity, Integer, null: true, description: "Maximální množství (null = neomezeno)"
    field :price_cents, Integer, null: false, description: "Cena v haléřích"
    field :price_decimal, Float, null: false, description: "Cena v korunách"
    field :currency, String, null: false, description: "Měna"
    field :description, String, null: true, description: "Popis cenové úrovně"
    field :active, Boolean, null: false, description: "Aktivní stav"
    field :quantity_range_description, String, null: false, description: "Popis rozsahu množství"
    field :savings_percentage, Float, null: false, description: "Procento úspory oproti základní ceně"

    def price_decimal
      object.price
    end

    def quantity_range_description
      object.quantity_range_description
    end

    def savings_percentage
      object.savings_compared_to_base_price
    end
  end
end
```

### ProductType Extension
```ruby
# app/graphql/types/product_type.rb - přidané fields
field :price_tiers, [Types::ProductPriceTierType], null: false, description: 'Cenové úrovně'
field :has_bulk_pricing, Boolean, null: false, description: 'Má množstevní slevy?'
field :price_for_quantity, Float, null: false do
  argument :quantity, Integer, required: true
  description 'Cena za kus při daném množství'
end
field :bulk_savings_for_quantity, Float, null: false do
  argument :quantity, Integer, required: true
  description 'Procento úspory při daném množství'
end

# Resolver methods
def price_tiers
  object.available_price_tiers
end

def has_bulk_pricing
  object.has_bulk_pricing?
end

def price_for_quantity(quantity:)
  object.price_for_quantity(quantity)
end

def bulk_savings_for_quantity(quantity:)
  object.bulk_savings_for_quantity(quantity)
end
```

### Mutations
```ruby
# app/graphql/mutations/create_price_tier.rb
module Mutations
  class CreatePriceTier < BaseMutation
    description 'Vytvoří novou cenovou úroveň pro produkt'

    argument :product_id, ID, required: true
    argument :tier_name, String, required: true
    argument :min_quantity, Integer, required: true
    argument :max_quantity, Integer, required: false
    argument :price_cents, Integer, required: true
    argument :description, String, required: false

    field :price_tier, Types::ProductPriceTierType, null: true
    field :errors, [String], null: false

    def resolve(product_id:, tier_name:, min_quantity:, price_cents:, **args)
      product = Product.find(product_id)

      price_tier = product.price_tiers.build(
        tier_name: tier_name,
        min_quantity: min_quantity,
        max_quantity: args[:max_quantity],
        price_cents: price_cents,
        description: args[:description]
      )

      if price_tier.save
        { price_tier: price_tier, errors: [] }
      else
        { price_tier: nil, errors: price_tier.errors.full_messages }
      end
    end
  end
end
```

---

## 💻 Frontend integrace

### GraphQL Queries
```graphql
# Získání produktů s bulk pricing
query GetProductsWithPricing {
  products {
    id
    name
    priceDecimal
    hasBulkPricing

    priceTiers {
      id
      tierName
      minQuantity
      maxQuantity
      priceDecimal
      quantityRangeDescription
      savingsPercentage
      description
    }

    # Dynamické ceny
    priceForQuantity(quantity: 1)
    priceForQuantity(quantity: 12)
    priceForQuantity(quantity: 120)

    # Úspory
    bulkSavingsForQuantity(quantity: 12)
    bulkSavingsForQuantity(quantity: 120)
  }
}
```

### React komponenta pro cenové tiers
```tsx
// components/PricingTiers.tsx
interface PricingTiersProps {
  product: {
    id: string;
    name: string;
    priceDecimal: number;
    priceTiers: PriceTier[];
    hasBulkPricing: boolean;
  };
  selectedQuantity: number;
  onQuantityChange: (quantity: number) => void;
}

export default function PricingTiers({ product, selectedQuantity, onQuantityChange }: PricingTiersProps) {
  if (!product.hasBulkPricing) {
    return (
      <div className="bg-gray-50 p-4 rounded-lg">
        <p className="text-lg font-semibold">{product.priceDecimal} CZK/ks</p>
        <p className="text-sm text-gray-600">Jednotná cena</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <h3 className="font-semibold text-lg">💰 Množstevní slevy</h3>

      <div className="grid gap-3">
        {product.priceTiers.map((tier) => {
          const isActive = selectedQuantity >= tier.minQuantity &&
                          (tier.maxQuantity === null || selectedQuantity <= tier.maxQuantity);

          return (
            <div
              key={tier.id}
              className={`p-4 border-2 rounded-lg cursor-pointer transition-all ${
                isActive
                  ? 'border-green-500 bg-green-50'
                  : 'border-gray-200 hover:border-blue-300'
              }`}
              onClick={() => onQuantityChange(tier.minQuantity)}
            >
              <div className="flex justify-between items-start">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-lg">
                      {tier.tierName.toUpperCase()}
                    </span>
                    {tier.savingsPercentage > 0 && (
                      <span className="bg-red-100 text-red-700 px-2 py-1 rounded text-xs font-medium">
                        -{tier.savingsPercentage}%
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-gray-600">{tier.quantityRangeDescription}</p>
                  {tier.description && (
                    <p className="text-xs text-gray-500 mt-1">{tier.description}</p>
                  )}
                </div>

                <div className="text-right">
                  <p className="text-xl font-bold text-green-600">
                    {tier.priceDecimal} CZK
                  </p>
                  <p className="text-sm text-gray-500">za kus</p>
                </div>
              </div>

              {isActive && (
                <div className="mt-2 pt-2 border-t border-green-200">
                  <p className="text-sm font-medium text-green-700">
                    ✓ Aktuální cena pro {selectedQuantity} kusů
                  </p>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

### Quantity selector s real-time pricing
```tsx
// components/QuantitySelector.tsx
interface QuantitySelectorProps {
  productId: string;
  onQuantityChange: (quantity: number, totalPrice: number) => void;
}

export default function QuantitySelector({ productId, onQuantityChange }: QuantitySelectorProps) {
  const [quantity, setQuantity] = useState(1);

  // GraphQL query pro real-time pricing
  const { data } = useQuery(GET_PRODUCT_PRICING, {
    variables: { id: productId, quantity },
    fetchPolicy: 'cache-and-network'
  });

  const currentPrice = data?.product?.priceForQuantity || 0;
  const savings = data?.product?.bulkSavingsForQuantity || 0;
  const totalPrice = currentPrice * quantity;

  const handleQuantityChange = (newQuantity: number) => {
    setQuantity(newQuantity);
    // Parent component dostane aktuální cenu
    onQuantityChange(newQuantity, totalPrice);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        <label className="font-medium">Množství:</label>
        <div className="flex items-center gap-2">
          <button
            onClick={() => handleQuantityChange(Math.max(1, quantity - 1))}
            className="px-3 py-1 border rounded hover:bg-gray-50"
          >
            -
          </button>
          <input
            type="number"
            value={quantity}
            onChange={(e) => handleQuantityChange(parseInt(e.target.value) || 1)}
            min="1"
            className="w-20 px-3 py-1 border rounded text-center"
          />
          <button
            onClick={() => handleQuantityChange(quantity + 1)}
            className="px-3 py-1 border rounded hover:bg-gray-50"
          >
            +
          </button>
        </div>
      </div>

      <div className="bg-blue-50 p-4 rounded-lg">
        <div className="flex justify-between items-center">
          <span className="font-medium">Cena za kus:</span>
          <span className="text-lg font-bold text-blue-600">
            {currentPrice.toFixed(2)} CZK
          </span>
        </div>

        <div className="flex justify-between items-center mt-2">
          <span className="font-medium">Celková cena:</span>
          <span className="text-xl font-bold">
            {totalPrice.toFixed(2)} CZK
          </span>
        </div>

        {savings > 0 && (
          <div className="mt-2 pt-2 border-t border-blue-200">
            <p className="text-sm text-green-600 font-medium">
              💰 Ušetříte {savings.toFixed(1)}% oproti jednotkové ceně!
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
```

---

## 🧪 Testing

### Model testy
```ruby
# spec/models/product_price_tier_spec.rb
RSpec.describe ProductPriceTier, type: :model do
  let(:product) { create(:product, price_cents: 10000) }

  describe 'validations' do
    it 'validates tier_name inclusion' do
      tier = build(:product_price_tier, product: product, tier_name: 'invalid')
      expect(tier).not_to be_valid
      expect(tier.errors[:tier_name]).to include('is not included in the list')
    end

    it 'validates min_quantity is positive' do
      tier = build(:product_price_tier, product: product, min_quantity: 0)
      expect(tier).not_to be_valid
    end

    it 'validates max_quantity is greater than min_quantity' do
      tier = build(:product_price_tier, product: product, min_quantity: 10, max_quantity: 5)
      expect(tier).not_to be_valid
      expect(tier.errors[:max_quantity]).to include('musí být větší nebo rovno min_quantity')
    end
  end

  describe 'business methods' do
    let(:tier) { create(:product_price_tier, product: product, min_quantity: 10, max_quantity: 50, price_cents: 8000) }

    it 'applies to quantity within range' do
      expect(tier.applies_to_quantity?(25)).to be true
      expect(tier.applies_to_quantity?(5)).to be false
      expect(tier.applies_to_quantity?(60)).to be false
    end

    it 'calculates savings compared to base price' do
      expect(tier.savings_compared_to_base_price).to eq(20.0) # (10000 - 8000) / 10000 * 100
    end

    it 'formats quantity range description' do
      expect(tier.quantity_range_description).to eq('10-50 kusů')
    end
  end
end

# spec/models/product_spec.rb - bulk pricing tests
RSpec.describe Product, type: :model do
  let(:product) { create(:product, price_cents: 10000) }

  describe 'bulk pricing methods' do
    before do
      create(:product_price_tier, product: product, tier_name: '1ks', min_quantity: 1, max_quantity: 9, price_cents: 10000)
      create(:product_price_tier, product: product, tier_name: '1bal', min_quantity: 10, max_quantity: 99, price_cents: 8000)
      create(:product_price_tier, product: product, tier_name: '10bal', min_quantity: 100, max_quantity: nil, price_cents: 6000)
    end

    it 'returns correct price for quantity' do
      expect(product.price_for_quantity(5)).to eq(100.0)   # 1ks tier
      expect(product.price_for_quantity(50)).to eq(80.0)   # 1bal tier
      expect(product.price_for_quantity(150)).to eq(60.0)  # 10bal tier
    end

    it 'calculates bulk savings correctly' do
      expect(product.bulk_savings_for_quantity(50)).to eq(20.0)  # (10000 - 8000) / 10000 * 100
      expect(product.bulk_savings_for_quantity(150)).to eq(40.0) # (10000 - 6000) / 10000 * 100
    end

    it 'identifies products with bulk pricing' do
      expect(product.has_bulk_pricing?).to be true
    end
  end
end
```

### GraphQL testy
```ruby
# spec/graphql/mutations/create_price_tier_spec.rb
RSpec.describe Mutations::CreatePriceTier, type: :graphql do
  let(:product) { create(:product) }
  let(:user) { create(:user, role: 'admin') }

  let(:mutation) do
    <<~GQL
      mutation CreatePriceTier($productId: ID!, $tierName: String!, $minQuantity: Int!, $priceCents: Int!) {
        createPriceTier(
          productId: $productId
          tierName: $tierName
          minQuantity: $minQuantity
          priceCents: $priceCents
        ) {
          priceTier {
            id
            tierName
            minQuantity
            priceCents
            quantityRangeDescription
          }
          errors
        }
      }
    GQL
  end

  it 'creates price tier successfully' do
    result = execute_graphql(
      query: mutation,
      variables: {
        productId: product.id,
        tierName: '1bal',
        minQuantity: 10,
        priceCents: 8000
      },
      current_user: user
    )

    expect(result['data']['createPriceTier']['priceTier']).to include(
      'tierName' => '1bal',
      'minQuantity' => 10,
      'priceCents' => 8000
    )
    expect(result['data']['createPriceTier']['errors']).to be_empty
  end
end
```

---

## 🚀 Příklady použití

### Seed data
```ruby
# db/seeds.rb excerpt
# Popping Pearls - množstevní slevy
product = Product.find_by(name: 'Popping Pearls - Marakuja')
[
  { tier_name: '1ks', min_quantity: 1, max_quantity: 11, price_cents: 25000, description: 'Jednotlivé balení' },
  { tier_name: '1bal', min_quantity: 12, max_quantity: 119, price_cents: 22000, description: 'Balení 12 kusů - úspora 12%' },
  { tier_name: '10bal', min_quantity: 120, max_quantity: nil, price_cents: 20000, description: 'Kartón 10 balení - úspora 20%' }
].each do |tier_attrs|
  product.price_tiers.create!(tier_attrs)
end
```

### Console testování
```ruby
# rails console
product = Product.first

# Zobrazit všechny cenové úrovně
product.available_price_tiers.each do |tier|
  puts "#{tier.tier_name}: #{tier.quantity_range_description} → #{tier.formatted_price}"
end

# Testovat různé množství
[1, 12, 50, 120, 500].each do |qty|
  price = product.price_for_quantity(qty)
  savings = product.bulk_savings_for_quantity(qty)
  puts "#{qty} kusů: #{price} CZK (úspora #{savings}%)"
end
```

### GraphQL testování
```bash
# GraphQL query pro testování
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { products { id name priceDecimal hasBulkPricing priceTiers { tierName minQuantity maxQuantity priceDecimal savingsPercentage } priceForQuantity(quantity: 12) bulkSavingsForQuantity(quantity: 12) } }"
  }'
```

---

## 📚 Related Documentation
- [INVENTORY_SYSTEM.md](./INVENTORY_SYSTEM.md) - Skladové hospodářství
- [ADDRESS_SYSTEM.md](./ADDRESS_SYSTEM.md) - Adresní management
- [FRONTEND_GUIDE.md](./FRONTEND_GUIDE.md) - Frontend implementace
- [GRAPHQL_GUIDE.md](./GRAPHQL_GUIDE.md) - GraphQL API reference

---

*Dokumentace aktualizována: 2025-01-18*