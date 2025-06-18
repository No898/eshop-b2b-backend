# 🏷️ Bulk Pricing System

Komplexní systém množstevních slev pro B2B e-commerce s českými specifiky (1ks/1bal/10bal).

## 📋 Obsah
- [🏗️ Přehled systému](#-přehled-systému)
- [💼 Business logika](#-business-logika)
- [📊 Database schema](#-database-schema)
- [🔧 GraphQL API](#-graphql-api)
- [💻 Frontend integrace](#-frontend-integrace)
- [🧪 Testování](#-testování)

---

## 🏗️ Přehled systému

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

## 📊 Database schema

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
```

### Model Implementation
```ruby
# app/models/product_price_tier.rb
class ProductPriceTier < ApplicationRecord
  belongs_to :product

  enum tier_name: {
    '1ks' => '1ks',
    '1bal' => '1bal',
    '10bal' => '10bal',
    'custom' => 'custom'
  }

  validates :tier_name, presence: true, inclusion: { in: tier_names.keys }
  validates :min_quantity, presence: true, numericality: { greater_than: 0 }
  validates :price_cents, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :for_quantity, ->(qty) { where('min_quantity <= ? AND (max_quantity IS NULL OR max_quantity >= ?)', qty, qty) }

  def price
    price_cents / 100.0
  end

  def applies_to_quantity?(quantity)
    quantity >= min_quantity && (max_quantity.nil? || quantity <= max_quantity)
  end

  def savings_compared_to_base_price
    return 0 unless product.price_cents > price_cents
    ((product.price_cents - price_cents) / product.price_cents.to_f * 100).round(2)
  end

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
# app/models/product.rb - bulk pricing methods
def price_for_quantity(quantity)
  tier = best_price_tier_for_quantity(quantity)
  return price if tier.nil?
  tier.price
end

def best_price_tier_for_quantity(quantity)
  price_tiers
    .active
    .for_quantity(quantity)
    .order(:price_cents, :priority)
    .first
end

def bulk_pricing?
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
```

---

## 🔧 GraphQL API

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
    field :savings_percentage, Float, null: false, description: "Procento úspory oproti základní ceně"

    def price_decimal
      object.price
    end

    def savings_percentage
      object.savings_compared_to_base_price
    end
  end
end
```

### ProductType Extension
```ruby
# app/graphql/types/product_type.rb - bulk pricing fields
field :price_tiers, [Types::ProductPriceTierType], null: false, description: 'Cenové úrovně'
field :bulk_pricing, Boolean, null: false, description: 'Má množstevní slevy?'
field :price_for_quantity, Float, null: false do
  argument :quantity, Integer, required: true
  description 'Cena za kus při daném množství'
end
field :bulk_savings_for_quantity, Float, null: false do
  argument :quantity, Integer, required: true
  description 'Procento úspory při daném množství'
end

def price_tiers
  object.price_tiers.active.order(:min_quantity)
end

def bulk_pricing
  object.bulk_pricing?
end

def price_for_quantity(quantity:)
  object.price_for_quantity(quantity)
end

def bulk_savings_for_quantity(quantity:)
  object.bulk_savings_for_quantity(quantity)
end
```

### Mutations
```graphql
# Vytvoření cenové úrovně
mutation CreatePriceTier {
  createPriceTier(
    productId: "1"
    tierName: "1bal"
    minQuantity: 12
    maxQuantity: 119
    priceCents: 22000
    description: "Balení 12 kusů - úspora 12%"
  ) {
    priceTier {
      id
      tierName
      minQuantity
      maxQuantity
      priceDecimal
      savingsPercentage
    }
    errors
  }
}
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
    bulkPricing

    priceTiers {
      id
      tierName
      minQuantity
      maxQuantity
      priceDecimal
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
    bulkPricing: boolean;
  };
  selectedQuantity: number;
  onQuantityChange: (quantity: number) => void;
}

export default function PricingTiers({ product, selectedQuantity, onQuantityChange }: PricingTiersProps) {
  if (!product.bulkPricing) {
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
                  <p className="text-sm text-gray-600">
                    {tier.minQuantity}{tier.maxQuantity ? `-${tier.maxQuantity}` : '+'} kusů
                  </p>
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

### Smart Quantity Selector
```tsx
// components/SmartQuantitySelector.tsx
interface SmartQuantitySelectorProps {
  productId: string;
  onQuantityChange: (quantity: number, totalPrice: number) => void;
}

export default function SmartQuantitySelector({ productId, onQuantityChange }: SmartQuantitySelectorProps) {
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

## 🧪 Testování

### GraphQL Testing
```graphql
# Test bulk pricing queries
query TestBulkPricing {
  products {
    id
    name
    priceDecimal
    bulkPricing

    priceTiers {
      tierName
      minQuantity
      maxQuantity
      priceDecimal
      savingsPercentage
    }

    priceForQuantity(quantity: 1)
    priceForQuantity(quantity: 12)
    priceForQuantity(quantity: 120)

    bulkSavingsForQuantity(quantity: 12)
    bulkSavingsForQuantity(quantity: 120)
  }
}

# Test vytvoření price tier
mutation TestCreatePriceTier {
  createPriceTier(
    productId: "1"
    tierName: "1bal"
    minQuantity: 12
    priceCents: 20000
  ) {
    priceTier {
      id
      tierName
      priceDecimal
      savingsPercentage
    }
    errors
  }
}
```

### Console Testing
```ruby
# rails console
product = Product.first

# Vytvoř price tiers
product.price_tiers.create!(
  tier_name: '1ks',
  min_quantity: 1,
  max_quantity: 11,
  price_cents: 25000
)

product.price_tiers.create!(
  tier_name: '1bal',
  min_quantity: 12,
  max_quantity: 119,
  price_cents: 22000
)

# Test pricing
[1, 12, 50, 120].each do |qty|
  price = product.price_for_quantity(qty)
  savings = product.bulk_savings_for_quantity(qty)
  puts "#{qty} kusů: #{price} CZK (úspora #{savings}%)"
end
```

---

## 🔗 Related Documentation
- **[GraphQL API](./graphql.md)** - Complete API reference
- **[Product Variants](./variants.md)** - Product variant system
- **[Inventory System](./inventory.md)** - Stock management

---

*Dokumentace aktualizována: 18.6.2025*