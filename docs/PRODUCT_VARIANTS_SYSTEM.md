# 🎨 Product Variants System

Kompletní systém pro správu variant produktů v B2B e-shopu. Umožňuje vytváření produktů s různými příchutěmi, velikostmi, barvami a dalšími atributy.

## 📋 Obsah
- [🏗️ Architektura systému](#️-architektura-systému)
- [📊 Databázová struktura](#-databázová-struktura)
- [🎯 Business logika](#-business-logika)
- [🔧 GraphQL API](#-graphql-api)
- [💻 Frontend integrace](#-frontend-integrace)
- [🧪 Testování](#-testování)

---

## 🏗️ Architektura systému

### Koncept
- **Parent Product** - základní produkt (např. "Popping Pearls")
- **Variant Products** - konkrétní varianty (Jahoda 3kg, Mango 5kg, atd.)
- **Variant Attributes** - typy atributů (flavor, size, color)
- **Variant Attribute Values** - konkrétní hodnoty (strawberry, large, red)

### Klíčové vlastnosti
- ✅ **Hierarchická struktura** - parent → children vztahy
- ✅ **Flexible atributy** - libovolné kombinace příchutí, velikostí, barev
- ✅ **Independent pricing** - každá varianta má vlastní cenu + bulk pricing
- ✅ **Independent inventory** - každá varianta má vlastní skladové zásoby
- ✅ **Automatic SKU generation** - automatické generování SKU pro varianty
- ✅ **Czech B2B specifics** - české názvy a business logika

---

## 📊 Databázová struktura

### Tabulky

#### `variant_attributes`
Typy atributů (příchuť, velikost, barva)
```sql
CREATE TABLE variant_attributes (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,           -- "flavor", "size", "color"
  display_name VARCHAR(100) NOT NULL,         -- "Příchuť", "Velikost", "Barva"
  description TEXT,
  sort_order INTEGER DEFAULT 0,
  active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

#### `variant_attribute_values`
Konkrétní hodnoty atributů (jahoda, velká, červená)
```sql
CREATE TABLE variant_attribute_values (
  id BIGSERIAL PRIMARY KEY,
  variant_attribute_id BIGINT NOT NULL REFERENCES variant_attributes(id),
  value VARCHAR(100) NOT NULL,                -- "strawberry", "large", "red"
  display_value VARCHAR(100) NOT NULL,        -- "Jahoda", "Velká", "Červená"
  color_code VARCHAR(7),                      -- "#FF0000" pro vizuální reprezentaci
  description TEXT,
  sort_order INTEGER DEFAULT 0,
  active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  UNIQUE(variant_attribute_id, value)
);
```

#### `products` (rozšířené)
```sql
-- Přidané sloupce pro variant support
ALTER TABLE products ADD COLUMN is_variant_parent BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE products ADD COLUMN parent_product_id BIGINT REFERENCES products(id);
ALTER TABLE products ADD COLUMN variant_sku VARCHAR(50) UNIQUE;
ALTER TABLE products ADD COLUMN variant_sort_order INTEGER DEFAULT 0;
```

#### `product_variant_attributes`
Junction tabulka - spojení produktů s jejich atributy
```sql
CREATE TABLE product_variant_attributes (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id),
  variant_attribute_value_id BIGINT NOT NULL REFERENCES variant_attribute_values(id),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  UNIQUE(product_id, variant_attribute_value_id)
);
```

### Indexy pro performance
```sql
-- Product variant indexy
CREATE INDEX idx_products_is_variant_parent ON products(is_variant_parent);
CREATE INDEX idx_products_parent_product_id ON products(parent_product_id);
CREATE INDEX idx_products_variant_sku ON products(variant_sku) WHERE variant_sku IS NOT NULL;
CREATE INDEX idx_products_variants_sorted ON products(parent_product_id, variant_sort_order);

-- Variant attribute indexy
CREATE INDEX idx_variant_attributes_active ON variant_attributes(active, sort_order);
CREATE INDEX idx_variant_attr_values_active ON variant_attribute_values(variant_attribute_id, active, sort_order);
```

### Database constraints
```sql
-- Variant logic constraint
ALTER TABLE products ADD CONSTRAINT chk_products_variant_logic
CHECK (
  (is_variant_parent = false AND parent_product_id IS NOT NULL) OR
  (is_variant_parent = true AND parent_product_id IS NULL) OR
  (is_variant_parent = false AND parent_product_id IS NULL)
);

-- Attribute name length
ALTER TABLE variant_attributes ADD CONSTRAINT chk_variant_attributes_name_length
CHECK (char_length(name) >= 2);

-- Attribute value length
ALTER TABLE variant_attribute_values ADD CONSTRAINT chk_variant_attribute_values_length
CHECK (char_length(value) >= 1);
```

---

## 🎯 Business logika

### Product Model rozšíření

#### Variant relationships
```ruby
class Product < ApplicationRecord
  # Parent-child relationships
  belongs_to :parent_product, class_name: 'Product', optional: true
  has_many :variants, class_name: 'Product', foreign_key: 'parent_product_id', dependent: :destroy

  # Variant attributes
  has_many :product_variant_attributes, dependent: :destroy
  has_many :variant_attribute_values, through: :product_variant_attributes
  has_many :variant_attributes, through: :variant_attribute_values
end
```

#### Variant scopes
```ruby
scope :parent_products, -> { where(is_variant_parent: true) }
scope :variants, -> { where(is_variant_parent: false).where.not(parent_product_id: nil) }
scope :standalone_products, -> { where(is_variant_parent: false, parent_product_id: nil) }
scope :with_variants, -> { includes(:variants) }
scope :ordered_variants, -> { order(:variant_sort_order, :name) }
```

#### Key business methods
```ruby
# Variant type checking
def variant_parent?
  is_variant_parent?
end

def variant_child?
  !is_variant_parent? && parent_product_id.present?
end

def standalone_product?
  !is_variant_parent? && parent_product_id.nil?
end

# Variant management
def has_variants?
  variant_parent? && variants.exists?
end

def available_variants
  variants.available.ordered_variants
end

def in_stock_variants
  variants.in_stock.ordered_variants
end

# Display name generation
def variant_display_name
  return name unless variant_child?

  attributes = variant_attribute_values.includes(:variant_attribute)
                                     .order('variant_attributes.sort_order')
                                     .pluck(:display_value)

  return name if attributes.empty?

  "#{parent_product.name} - #{attributes.join(', ')}"
end

# Attribute accessors
def flavor
  variant_attributes_hash['flavor']
end

def size
  variant_attributes_hash['size']
end

def color
  variant_attributes_hash['color']
end

# SKU generation
def generate_variant_sku!
  return unless variant_child?

  base_sku = parent_product.id.to_s.rjust(4, '0')
  variant_codes = variant_attribute_values
                    .joins(:variant_attribute)
                    .order('variant_attributes.sort_order')
                    .pluck(:value)
                    .map { |v| v.first(3).upcase }

  self.variant_sku = "#{base_sku}-#{variant_codes.join('-')}"
  save!
end

# Variant creation
def create_variant!(attributes_hash, **product_attributes)
  raise "Only parent products can create variants" unless variant_parent?

  transaction do
    # Create the variant product
    variant = variants.create!(
      name: product_attributes[:name] || name,
      price_cents: product_attributes[:price_cents] || price_cents,
      currency: currency,
      quantity: product_attributes[:quantity] || 0,
      low_stock_threshold: product_attributes[:low_stock_threshold] || low_stock_threshold,
      available: product_attributes.fetch(:available, true),
      variant_sort_order: product_attributes[:variant_sort_order] || variants.count,
      **product_attributes.except(:name, :price_cents, :quantity, :low_stock_threshold, :available, :variant_sort_order)
    )

    # Assign variant attributes
    attributes_hash.each do |attribute_name, value_id|
      variant_value = VariantAttributeValue.find(value_id)
      variant.product_variant_attributes.create!(variant_attribute_value: variant_value)
    end

    # Generate SKU
    variant.generate_variant_sku!

    variant
  end
end
```

### VariantAttribute Model
```ruby
class VariantAttribute < ApplicationRecord
  has_many :variant_attribute_values, dependent: :destroy
  has_many :product_variant_attributes, through: :variant_attribute_values
  has_many :products, through: :product_variant_attributes

  validates :name, presence: true, uniqueness: { case_sensitive: false },
                   length: { minimum: 2, maximum: 50 },
                   format: { with: /\A[a-z_]+\z/ }
  validates :display_name, presence: true, length: { minimum: 2, maximum: 100 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :display_name) }

  # Convenience methods for common attributes
  def self.find_or_create_flavor!
    find_or_create_by!(name: 'flavor') do |attr|
      attr.display_name = 'Příchuť'
      attr.description = 'Chuťová varianta produktu'
      attr.sort_order = 1
    end
  end

  def self.find_or_create_size!
    find_or_create_by!(name: 'size') do |attr|
      attr.display_name = 'Velikost'
      attr.description = 'Velikostní varianta produktu'
      attr.sort_order = 2
    end
  end

  def active_values
    variant_attribute_values.active.ordered
  end
end
```

### VariantAttributeValue Model
```ruby
class VariantAttributeValue < ApplicationRecord
  belongs_to :variant_attribute
  has_many :product_variant_attributes, dependent: :destroy
  has_many :products, through: :product_variant_attributes

  validates :value, presence: true, length: { minimum: 1, maximum: 100 },
                   uniqueness: { scope: :variant_attribute_id, case_sensitive: false }
  validates :display_value, presence: true, length: { minimum: 1, maximum: 100 }
  validates :color_code, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :display_value) }
  scope :for_attribute, ->(attribute_name) { joins(:variant_attribute).where(variant_attributes: { name: attribute_name }) }

  # Convenience scopes
  def self.flavors
    for_attribute('flavor').active.ordered
  end

  def self.sizes
    for_attribute('size').active.ordered
  end

  def self.colors
    for_attribute('color').active.ordered
  end

  # Factory methods
  def self.create_flavor!(value, display_value, color_code: nil, description: nil)
    flavor_attr = VariantAttribute.find_or_create_flavor!
    create!(
      variant_attribute: flavor_attr,
      value: value,
      display_value: display_value,
      color_code: color_code,
      description: description
    )
  end
end
```

---

## 🔧 GraphQL API

### Types

#### VariantAttributeType
```ruby
module Types
  class VariantAttributeType < Types::BaseObject
    description "Atribut varianty produktu (příchuť, velikost, barva)"

    field :id, ID, null: false
    field :name, String, null: false, description: "Systémový název (flavor, size, color)"
    field :display_name, String, null: false, description: "Zobrazovaný název (Příchuť, Velikost, Barva)"
    field :description, String, null: true
    field :sort_order, Integer, null: false
    field :active, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :values, [Types::VariantAttributeValueType], null: false
    field :active_values, [Types::VariantAttributeValueType], null: false
    field :values_count, Integer, null: false

    # Helper fields
    field :is_flavor, Boolean, null: false, method: :attribute_flavor?
    field :is_size, Boolean, null: false, method: :attribute_size?
    field :is_color, Boolean, null: false, method: :attribute_color?
  end
end
```

#### VariantAttributeValueType
```ruby
module Types
  class VariantAttributeValueType < Types::BaseObject
    description "Hodnota atributu varianty (jahoda, velká, červená)"

    field :id, ID, null: false
    field :value, String, null: false, description: "Systémová hodnota (strawberry, large, red)"
    field :display_value, String, null: false, description: "Zobrazovaná hodnota (Jahoda, Velká, Červená)"
    field :color_code, String, null: true, description: "Hex kód barvy (#FF0000)"
    field :description, String, null: true
    field :sort_order, Integer, null: false
    field :active, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :variant_attribute, Types::VariantAttributeType, null: false
    field :products_count, Integer, null: false

    # Helper fields
    field :attribute_name, String, null: false
    field :attribute_display_name, String, null: false
    field :has_color, Boolean, null: false, method: :has_color?
    field :is_flavor, Boolean, null: false, method: :flavor?
    field :is_size, Boolean, null: false, method: :size?
    field :is_color, Boolean, null: false, method: :color?
    field :display_with_attribute, String, null: false
  end
end
```

#### ProductType rozšíření
```ruby
# PRODUCT VARIANTS - Varianty produktu
field :is_variant_parent, Boolean, null: false, description: 'Je produkt rodičem variant?'
field :is_variant_child, Boolean, null: false, description: 'Je produkt variantou jiného produktu?'
field :is_standalone_product, Boolean, null: false, description: 'Je produkt samostatný (bez variant)?'
field :parent_product, Types::ProductType, null: true, description: 'Rodičovský produkt'
field :variants, [Types::ProductType], null: false, description: 'Varianty tohoto produktu'
field :available_variants, [Types::ProductType], null: false, description: 'Dostupné varianty'
field :in_stock_variants, [Types::ProductType], null: false, description: 'Varianty skladem'
field :has_variants, Boolean, null: false, description: 'Má produkt varianty?'
field :variants_count, Integer, null: false, description: 'Počet variant'
field :variant_sku, String, null: true, description: 'SKU varianty'
field :variant_sort_order, Integer, null: false, description: 'Pořadí varianty'
field :variant_display_name, String, null: false, description: 'Zobrazovaný název varianty'

# VARIANT ATTRIBUTES - Atributy variant
field :variant_attributes, [Types::VariantAttributeType], null: false
field :variant_attribute_values, [Types::VariantAttributeValueType], null: false
field :flavor, Types::VariantAttributeValueType, null: true, description: 'Příchuť (pokud má)'
field :size, Types::VariantAttributeValueType, null: true, description: 'Velikost (pokud má)'
field :color, Types::VariantAttributeValueType, null: true, description: 'Barva (pokud má)'
field :has_flavor, Boolean, null: false, description: 'Má produkt příchuť?'
field :has_size, Boolean, null: false, description: 'Má produkt velikost?'
field :has_color, Boolean, null: false, description: 'Má produkt barvu?'
```

### Queries

#### Seznam variant attributes
```graphql
query GetVariantAttributes {
  variantAttributes {
    id
    name
    displayName
    description
    sortOrder
    active
    isColor
    isFlavor
    isSize
    valuesCount

    activeValues {
      id
      value
      displayValue
      colorCode
      description
      sortOrder
    }
  }
}
```

#### Produkty s variantami
```graphql
query GetProductsWithVariants {
  products {
    id
    name
    priceDecimal
    isVariantParent
    isVariantChild
    hasVariants
    variantsCount

    # Pro parent produkty
    variants {
      id
      name
      variantDisplayName
      priceDecimal
      quantity
      inStock
      variantSku

      # Atributy variant
      flavor {
        displayValue
        colorCode
      }
      size {
        displayValue
      }
      color {
        displayValue
        colorCode
      }

      # Bulk pricing
      hasBulkPricing
      priceForQuantity(quantity: 1)
      priceForQuantity(quantity: 12)
      priceForQuantity(quantity: 120)
    }

    # Pro variant produkty
    parentProduct {
      id
      name
    }

    variantAttributeValues {
      attributeName
      attributeDisplayName
      displayValue
      colorCode
    }
  }
}
```

#### Konkrétní příchutě/velikosti
```graphql
query GetFlavorsSizesColors {
  flavors {
    id
    value
    displayValue
    colorCode
    description
    productsCount
  }

  sizes {
    id
    value
    displayValue
    description
    productsCount
  }

  colors {
    id
    value
    displayValue
    colorCode
    productsCount
  }
}
```

### Mutations

#### Vytvoření variant
```graphql
mutation CreateProductVariant {
  createProductVariant(
    parentProductId: "1"
    variantAttributes: {
      flavor: 5,    # ID of strawberry flavor
      size: 2       # ID of medium size
    }
    priceCents: 26000
    quantity: 50
    description: "Praskající kuličky s příchutí jahoda - balení 3kg"
    weightValue: 3.0
    weightUnit: "kg"
  ) {
    variant {
      id
      name
      variantDisplayName
      variantSku
      priceDecimal
      quantity

      flavor {
        displayValue
        colorCode
      }
      size {
        displayValue
      }

      parentProduct {
        name
      }
    }
    errors
  }
}
```

---

## 💻 Frontend integrace

### React komponenty

#### VariantSelector
```tsx
// components/VariantSelector.tsx
import { useState } from 'react';
import { useQuery } from '@apollo/client';

interface VariantSelectorProps {
  parentProduct: {
    id: string;
    name: string;
    variants: ProductVariant[];
  };
  onVariantSelect: (variant: ProductVariant) => void;
}

export default function VariantSelector({ parentProduct, onVariantSelect }: VariantSelectorProps) {
  const [selectedAttributes, setSelectedAttributes] = useState<Record<string, string>>({});

  // Group variants by attributes for easier selection
  const variantsByAttributes = parentProduct.variants.reduce((acc, variant) => {
    const key = variant.variantAttributeValues
      .map(attr => `${attr.attributeName}:${attr.value}`)
      .join('|');
    acc[key] = variant;
    return acc;
  }, {} as Record<string, ProductVariant>);

  // Get available attribute values
  const availableAttributes = parentProduct.variants.reduce((acc, variant) => {
    variant.variantAttributeValues.forEach(attr => {
      if (!acc[attr.attributeName]) {
        acc[attr.attributeName] = {
          displayName: attr.attributeDisplayName,
          values: []
        };
      }

      const exists = acc[attr.attributeName].values.find(v => v.value === attr.value);
      if (!exists) {
        acc[attr.attributeName].values.push({
          value: attr.value,
          displayValue: attr.displayValue,
          colorCode: attr.colorCode
        });
      }
    });
    return acc;
  }, {} as Record<string, any>);

  const handleAttributeSelect = (attributeName: string, value: string) => {
    const newSelection = { ...selectedAttributes, [attributeName]: value };
    setSelectedAttributes(newSelection);

    // Find matching variant
    const attributeKey = Object.entries(newSelection)
      .map(([attr, val]) => `${attr}:${val}`)
      .sort()
      .join('|');

    const matchingVariant = Object.entries(variantsByAttributes).find(([key]) => {
      const keyParts = key.split('|').sort();
      const selectionParts = attributeKey.split('|').sort();
      return keyParts.every(part => selectionParts.includes(part));
    });

    if (matchingVariant) {
      onVariantSelect(matchingVariant[1]);
    }
  };

  return (
    <div className="variant-selector space-y-6">
      <h3 className="text-lg font-semibold">{parentProduct.name}</h3>

      {Object.entries(availableAttributes).map(([attributeName, attributeData]) => (
        <div key={attributeName} className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">
            {attributeData.displayName}
          </label>

          <div className="flex flex-wrap gap-2">
            {attributeData.values.map((value: any) => {
              const isSelected = selectedAttributes[attributeName] === value.value;

              return (
                <button
                  key={value.value}
                  onClick={() => handleAttributeSelect(attributeName, value.value)}
                  className={`px-4 py-2 rounded-lg border-2 transition-all ${
                    isSelected
                      ? 'border-blue-500 bg-blue-50 text-blue-700'
                      : 'border-gray-300 hover:border-gray-400 text-gray-700'
                  }`}
                  style={value.colorCode ? {
                    borderLeftColor: value.colorCode,
                    borderLeftWidth: '4px'
                  } : {}}
                >
                  {value.displayValue}
                  {value.colorCode && (
                    <span
                      className="inline-block w-3 h-3 rounded-full ml-2"
                      style={{ backgroundColor: value.colorCode }}
                    />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
```

#### VariantCard
```tsx
// components/VariantCard.tsx
interface VariantCardProps {
  variant: ProductVariant;
  onAddToCart: (variant: ProductVariant, quantity: number) => void;
}

export default function VariantCard({ variant, onAddToCart }: VariantCardProps) {
  const [quantity, setQuantity] = useState(1);

  return (
    <div className="variant-card bg-white border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-4">
        <div>
          <h4 className="text-lg font-semibold text-gray-900">
            {variant.variantDisplayName}
          </h4>
          <p className="text-sm text-gray-600 mt-1">
            SKU: {variant.variantSku}
          </p>
        </div>

        <div className="text-right">
          <p className="text-2xl font-bold text-green-600">
            {variant.priceDecimal} CZK
          </p>
          {variant.hasBulkPricing && (
            <p className="text-xs text-gray-500">
              od {variant.priceForQuantity(12)} CZK při 12+ ks
            </p>
          )}
        </div>
      </div>

      {/* Variant attributes */}
      <div className="flex flex-wrap gap-2 mb-4">
        {variant.flavor && (
          <span
            className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-pink-100 text-pink-800"
            style={variant.flavor.colorCode ? {
              backgroundColor: variant.flavor.colorCode + '20',
              color: variant.flavor.colorCode
            } : {}}
          >
            🍓 {variant.flavor.displayValue}
          </span>
        )}

        {variant.size && (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
            📦 {variant.size.displayValue}
          </span>
        )}

        {variant.color && (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
            <span
              className="w-3 h-3 rounded-full mr-1"
              style={{ backgroundColor: variant.color.colorCode }}
            />
            {variant.color.displayValue}
          </span>
        )}
      </div>

      {/* Stock status */}
      <div className="mb-4">
        {variant.inStock ? (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
            ✅ Skladem ({variant.quantity} ks)
          </span>
        ) : (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
            ❌ Vyprodáno
          </span>
        )}
      </div>

      {/* Quantity selector and add to cart */}
      {variant.inStock && (
        <div className="flex items-center gap-4">
          <div className="flex items-center border border-gray-300 rounded-lg">
            <button
              onClick={() => setQuantity(Math.max(1, quantity - 1))}
              className="px-3 py-2 text-gray-600 hover:text-gray-800"
            >
              −
            </button>
            <input
              type="number"
              value={quantity}
              onChange={(e) => setQuantity(Math.max(1, parseInt(e.target.value) || 1))}
              min="1"
              max={variant.quantity}
              className="w-16 px-3 py-2 text-center border-l border-r border-gray-300 focus:outline-none"
            />
            <button
              onClick={() => setQuantity(Math.min(variant.quantity, quantity + 1))}
              className="px-3 py-2 text-gray-600 hover:text-gray-800"
            >
              +
            </button>
          </div>

          <button
            onClick={() => onAddToCart(variant, quantity)}
            className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            Přidat do košíku
          </button>
        </div>
      )}
    </div>
  );
}
```

### GraphQL Queries pro frontend
```typescript
// queries/variants.ts
import { gql } from '@apollo/client';

export const GET_PRODUCTS_WITH_VARIANTS = gql`
  query GetProductsWithVariants {
    products {
      id
      name
      description
      priceDecimal
      isVariantParent
      isVariantChild
      hasVariants
      variantsCount

      variants {
        id
        name
        variantDisplayName
        priceDecimal
        quantity
        inStock
        variantSku

        flavor {
          id
          value
          displayValue
          colorCode
        }

        size {
          id
          value
          displayValue
        }

        color {
          id
          value
          displayValue
          colorCode
        }

        hasBulkPricing
        priceForQuantity(quantity: 1)
        priceForQuantity(quantity: 12)
        priceForQuantity(quantity: 120)

        priceTiers {
          tierName
          minQuantity
          maxQuantity
          priceDecimal
          savingsPercentage
        }
      }

      parentProduct {
        id
        name
      }

      variantAttributeValues {
        attributeName
        attributeDisplayName
        value
        displayValue
        colorCode
      }
    }
  }
`;

export const GET_VARIANT_ATTRIBUTES = gql`
  query GetVariantAttributes {
    variantAttributes {
      id
      name
      displayName
      description
      sortOrder
      isFlavor
      isSize
      isColor

      activeValues {
        id
        value
        displayValue
        colorCode
        description
        sortOrder
      }
    }
  }
`;

export const CREATE_PRODUCT_VARIANT = gql`
  mutation CreateProductVariant(
    $parentProductId: ID!
    $variantAttributes: JSON!
    $priceCents: Int!
    $quantity: Int!
    $description: String
    $weightValue: Float
    $weightUnit: String
  ) {
    createProductVariant(
      parentProductId: $parentProductId
      variantAttributes: $variantAttributes
      priceCents: $priceCents
      quantity: $quantity
      description: $description
      weightValue: $weightValue
      weightUnit: $weightUnit
    ) {
      variant {
        id
        name
        variantDisplayName
        variantSku
        priceDecimal
        quantity
        inStock

        flavor {
          displayValue
          colorCode
        }

        size {
          displayValue
        }

        parentProduct {
          id
          name
        }
      }
      errors
    }
  }
`;
```

---

## 🧪 Testování

### Model testy
```ruby
# spec/models/product_spec.rb
RSpec.describe Product, type: :model do
  describe 'variant functionality' do
    let(:parent_product) { create(:product, is_variant_parent: true) }
    let(:flavor_value) { create(:variant_attribute_value, :strawberry) }
    let(:size_value) { create(:variant_attribute_value, :medium) }

    describe '#create_variant!' do
      it 'creates variant with attributes' do
        variant = parent_product.create_variant!(
          { 'flavor' => flavor_value.id, 'size' => size_value.id },
          price_cents: 26000,
          quantity: 50
        )

        expect(variant).to be_persisted
        expect(variant.variant_child?).to be true
        expect(variant.parent_product).to eq parent_product
        expect(variant.flavor).to eq flavor_value
        expect(variant.size).to eq size_value
        expect(variant.variant_sku).to be_present
      end
    end

    describe '#variant_display_name' do
      it 'generates display name from attributes' do
        variant = parent_product.create_variant!(
          { 'flavor' => flavor_value.id, 'size' => size_value.id },
          price_cents: 26000,
          quantity: 50
        )

        expected_name = "#{parent_product.name} - #{flavor_value.display_value}, #{size_value.display_value}"
        expect(variant.variant_display_name).to eq expected_name
      end
    end
  end
end

# spec/models/variant_attribute_spec.rb
RSpec.describe VariantAttribute, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(50) }
    it { should allow_value('flavor').for(:name) }
    it { should_not allow_value('Flavor').for(:name) }
    it { should_not allow_value('flavor name').for(:name) }
  end

  describe '.find_or_create_flavor!' do
    it 'creates flavor attribute' do
      expect { VariantAttribute.find_or_create_flavor! }.to change(VariantAttribute, :count).by(1)

      flavor_attr = VariantAttribute.find_by(name: 'flavor')
      expect(flavor_attr.display_name).to eq 'Příchuť'
      expect(flavor_attr.sort_order).to eq 1
    end
  end
end
```

### GraphQL testy
```ruby
# spec/graphql/queries/variant_attributes_spec.rb
RSpec.describe 'VariantAttributes Query', type: :request do
  let(:user) { create(:user) }
  let!(:flavor_attr) { create(:variant_attribute, :flavor) }
  let!(:size_attr) { create(:variant_attribute, :size) }
  let!(:strawberry) { create(:variant_attribute_value, :strawberry, variant_attribute: flavor_attr) }

  let(:query) do
    <<~GQL
      query {
        variantAttributes {
          id
          name
          displayName
          isFlavor
          isSize
          valuesCount
          activeValues {
            id
            displayValue
            colorCode
          }
        }
      }
    GQL
  end

  it 'returns variant attributes with values' do
    post '/graphql', params: { query: query }, headers: auth_headers(user)

    expect(response).to have_http_status(:success)

    data = JSON.parse(response.body)['data']['variantAttributes']
    expect(data).to have_attributes(size: 2)

    flavor_data = data.find { |attr| attr['name'] == 'flavor' }
    expect(flavor_data).to include(
      'displayName' => 'Příchuť',
      'isFlavor' => true,
      'valuesCount' => 1
    )
    expect(flavor_data['activeValues']).to have_attributes(size: 1)
  end
end

# spec/graphql/mutations/create_product_variant_spec.rb
RSpec.describe 'CreateProductVariant Mutation', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:parent_product) { create(:product, is_variant_parent: true) }
  let(:flavor_value) { create(:variant_attribute_value, :strawberry) }
  let(:size_value) { create(:variant_attribute_value, :medium) }

  let(:mutation) do
    <<~GQL
      mutation CreateProductVariant(
        $parentProductId: ID!
        $variantAttributes: JSON!
        $priceCents: Int!
        $quantity: Int!
      ) {
        createProductVariant(
          parentProductId: $parentProductId
          variantAttributes: $variantAttributes
          priceCents: $priceCents
          quantity: $quantity
        ) {
          variant {
            id
            variantDisplayName
            variantSku
            priceDecimal
            flavor {
              displayValue
            }
            size {
              displayValue
            }
          }
          errors
        }
      }
    GQL
  end

  let(:variables) do
    {
      parentProductId: parent_product.id,
      variantAttributes: {
        flavor: flavor_value.id,
        size: size_value.id
      },
      priceCents: 26000,
      quantity: 50
    }
  end

  it 'creates product variant successfully' do
    expect {
      post '/graphql',
           params: { query: mutation, variables: variables },
           headers: auth_headers(admin)
    }.to change(Product, :count).by(1)

    expect(response).to have_http_status(:success)

    data = JSON.parse(response.body)['data']['createProductVariant']
    expect(data['errors']).to be_empty
    expect(data['variant']).to include(
      'priceDecimal' => 260.0,
      'variantSku' => be_present
    )
    expect(data['variant']['flavor']['displayValue']).to eq 'Jahoda'
    expect(data['variant']['size']['displayValue']).to eq 'Střední (3kg)'
  end

  it 'requires admin permissions' do
    customer = create(:user, :customer)

    post '/graphql',
         params: { query: mutation, variables: variables },
         headers: auth_headers(customer)

    data = JSON.parse(response.body)['data']['createProductVariant']
    expect(data['errors']).to include('Nemáte oprávnění vytvářet varianty')
    expect(data['variant']).to be_nil
  end
end
```

### Factory definitions
```ruby
# spec/factories/variant_attributes.rb
FactoryBot.define do
  factory :variant_attribute do
    name { 'flavor' }
    display_name { 'Příchuť' }
    description { 'Chuťová varianta produktu' }
    sort_order { 1 }
    active { true }

    trait :flavor do
      name { 'flavor' }
      display_name { 'Příchuť' }
      sort_order { 1 }
    end

    trait :size do
      name { 'size' }
      display_name { 'Velikost' }
      sort_order { 2 }
    end

    trait :color do
      name { 'color' }
      display_name { 'Barva' }
      sort_order { 3 }
    end
  end
end

# spec/factories/variant_attribute_values.rb
FactoryBot.define do
  factory :variant_attribute_value do
    association :variant_attribute
    value { 'strawberry' }
    display_value { 'Jahoda' }
    color_code { '#FF6B6B' }
    sort_order { 1 }
    active { true }

    trait :strawberry do
      value { 'strawberry' }
      display_value { 'Jahoda' }
      color_code { '#FF6B6B' }
    end

    trait :mango do
      value { 'mango' }
      display_value { 'Mango' }
      color_code { '#FFD93D' }
    end

    trait :medium do
      value { 'medium' }
      display_value { 'Střední (3kg)' }
      color_code { nil }
    end

    trait :large do
      value { 'large' }
      display_value { 'Velké (5kg)' }
      color_code { nil }
    end
  end
end
```

---

## 🎯 Výhody systému

### Pro B2B zákazníky
- ✅ **Jasný přehled variant** - všechny příchutě a velikosti na jednom místě
- ✅ **Bulk pricing per variant** - každá varianta má vlastní množstevní slevy
- ✅ **Real-time stock info** - aktuální skladové zásoby pro každou variantu
- ✅ **Visual representation** - barevné kódy pro snadnou identifikaci
- ✅ **Czech localization** - české názvy a terminologie

### Pro administrátory
- ✅ **Flexible attribute system** - libovolné kombinace atributů
- ✅ **Automatic SKU generation** - automatické generování SKU kódů
- ✅ **Independent pricing** - každá varianta má vlastní cenu
- ✅ **Bulk operations** - možnost hromadných operací
- ✅ **Audit trail** - kompletní tracking změn

### Pro vývojáře
- ✅ **Clean architecture** - čistá databázová struktura
- ✅ **Type safety** - silné typování v GraphQL
- ✅ **Performance optimized** - správné indexy a eager loading
- ✅ **Test coverage** - kompletní testovací pokrytí
- ✅ **Documentation** - detailní dokumentace

---

## 🚀 Budoucí rozšíření

- **Bulk variant creation** - hromadné vytváření variant
- **Variant templates** - šablony pro časté kombinace
- **Advanced filtering** - pokročilé filtrování podle atributů
- **Variant analytics** - statistiky prodejů podle variant
- **Import/Export** - hromadný import variant z CSV
- **Variant images** - specifické obrázky pro každou variantu

---

**Product Variants System je připraven pro produkční nasazení!** 🎉