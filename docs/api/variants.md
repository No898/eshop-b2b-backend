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

---

## 🎯 Business logika

### Product Model rozšíření
```ruby
class Product < ApplicationRecord
  # Parent-child relationships
  belongs_to :parent_product, class_name: 'Product', optional: true
  has_many :variants, class_name: 'Product', foreign_key: 'parent_product_id', dependent: :destroy

  # Variant attributes
  has_many :product_variant_attributes, dependent: :destroy
  has_many :variant_attribute_values, through: :product_variant_attributes
  has_many :variant_attributes, through: :variant_attribute_values

  # Scopes
  scope :parent_products, -> { where(is_variant_parent: true) }
  scope :variants, -> { where(is_variant_parent: false).where.not(parent_product_id: nil) }
  scope :standalone_products, -> { where(is_variant_parent: false, parent_product_id: nil) }

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
  def available_variants
    variants.available.order(:variant_sort_order, :name)
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

  # Create variant helper
  def create_variant!(attributes)
    raise 'Only parent products can create variants' unless variant_parent?

    variant = variants.build(
      name: generate_variant_name(attributes),
      description: description,
      price_cents: price_cents,
      currency: currency,
      available: true,
      variant_sku: generate_variant_sku(attributes),
      is_variant_parent: false,
      parent_product: self
    )

    variant.save!

    # Assign variant attributes
    attributes.each do |attr_name, value_name|
      attr = VariantAttribute.find_by(name: attr_name)
      value = attr&.values&.find_by(value: value_name)

      if attr && value
        variant.product_variant_attributes.create!(variant_attribute_value: value)
      end
    end

    variant
  end

  private

  def variant_attributes_hash
    @variant_attributes_hash ||= variant_attribute_values
      .joins(:variant_attribute)
      .pluck('variant_attributes.name', :display_value)
      .to_h
  end

  def generate_variant_name(attributes)
    attribute_names = attributes.values.map(&:humanize).join(' ')
    "#{name} - #{attribute_names}"
  end

  def generate_variant_sku(attributes)
    base_sku = id.to_s.rjust(4, '0')
    attr_codes = attributes.map { |k, v| v.first(3).upcase }.join('-')
    "#{base_sku}-#{attr_codes}"
  end
end
```

---

## 🔧 GraphQL API

### VariantAttributeType
```ruby
module Types
  class VariantAttributeType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false, description: 'Interní název atributu'
    field :display_name, String, null: false, description: 'Zobrazovaný název'
    field :description, String, null: true, description: 'Popis atributu'
    field :sort_order, Integer, null: false, description: 'Pořadí řazení'
    field :active, Boolean, null: false, description: 'Aktivní stav'

    field :values, [Types::VariantAttributeValueType], null: false, description: 'Dostupné hodnoty'

    def values
      object.values.active.order(:sort_order, :display_value)
    end
  end
end
```

### ProductType Extension (Variants)
```ruby
# app/graphql/types/product_type.rb - variant fields
field :is_variant_parent, Boolean, null: false, description: 'Je nadřazený produkt s variantami?'
field :variant_child, Boolean, null: false, description: 'Je varianta jiného produktu?'
field :standalone_product, Boolean, null: false, description: 'Je samostatný produkt?'

field :parent_product, Types::ProductType, null: true, description: 'Nadřazený produkt'
field :variants, [Types::ProductType], null: false, description: 'Dostupné varianty'
field :variant_count, Integer, null: false, description: 'Počet variant'

field :variant_sku, String, null: true, description: 'SKU varianty'
field :variant_display_name, String, null: false, description: 'Zobrazovaný název varianty'

field :variant_attributes, [Types::VariantAttributeType], null: false, description: 'Atributy varianty'
field :flavor, String, null: true, description: 'Příchuť'
field :size, String, null: true, description: 'Velikost'
field :color, String, null: true, description: 'Barva'

# Resolvers
def variant_child
  object.variant_child?
end

def standalone_product
  object.standalone_product?
end

def variants
  object.available_variants
end

def variant_count
  object.variants.available.count
end

def variant_display_name
  object.variant_display_name
end

def variant_attributes
  object.variant_attributes.active.order(:sort_order)
end

def flavor
  object.flavor
end

def size
  object.size
end

def color
  object.color
end
```

### Variant Queries
```ruby
# app/graphql/types/query_type.rb - variant queries
field :variant_attributes, [Types::VariantAttributeType], null: false do
  description 'Všechny dostupné atributy variant'
end

field :variant_attribute_values, [Types::VariantAttributeValueType], null: false do
  argument :attribute_name, String, required: true
  description 'Hodnoty pro konkrétní atribut'
end

field :flavors, [Types::VariantAttributeValueType], null: false do
  description 'Dostupné příchutě'
end

field :sizes, [Types::VariantAttributeValueType], null: false do
  description 'Dostupné velikosti'
end

field :colors, [Types::VariantAttributeValueType], null: false do
  description 'Dostupné barvy'
end

# Resolvers
def variant_attributes
  VariantAttribute.active.order(:sort_order)
end

def variant_attribute_values(attribute_name:)
  attribute = VariantAttribute.find_by(name: attribute_name)
  return [] unless attribute
  attribute.values.active.order(:sort_order)
end

def flavors
  variant_attribute_values(attribute_name: 'flavor')
end

def sizes
  variant_attribute_values(attribute_name: 'size')
end

def colors
  variant_attribute_values(attribute_name: 'color')
end
```

### CreateProductVariant Mutation
```ruby
module Mutations
  class CreateProductVariant < BaseMutation
    description 'Vytvoří novou variantu produktu (pouze admin)'

    argument :parent_product_id, ID, required: true
    argument :attributes, GraphQL::Types::JSON, required: true
    argument :price_cents, Integer, required: false
    argument :description, String, required: false

    field :variant, Types::ProductType, null: true
    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(parent_product_id:, attributes:, **args)
      authorize_admin!

      parent_product = Product.find(parent_product_id)

      unless parent_product.variant_parent?
        return {
          variant: nil,
          success: false,
          errors: ['Produkt není nastaven jako nadřazený pro varianty']
        }
      end

      variant = parent_product.create_variant!(attributes)

      # Update price if provided
      if args[:price_cents]
        variant.update!(price_cents: args[:price_cents])
      end

      {
        variant: variant,
        success: true,
        errors: []
      }
    rescue => error
      {
        variant: nil,
        success: false,
        errors: [error.message]
      }
    end
  end
end
```

---

## 💻 Frontend integrace

### GraphQL Queries
```graphql
# Produkty s variantami
query GetProductsWithVariants {
  products {
    id
    name
    priceDecimal

    # Variant info
    isVariantParent
    variantChild
    standaloneProduct
    variantCount
    variantDisplayName
    variantSku

    # Parent/variants relationships
    parentProduct {
      id
      name
    }

    variants {
      id
      name
      variantDisplayName
      priceDecimal
      flavor
      size
      color
      inStock
    }

    # Variant attributes
    variantAttributes {
      id
      name
      displayName
      values {
        id
        value
        displayValue
        colorCode
      }
    }
  }
}

# Dostupné atributy variant
query GetVariantAttributes {
  variantAttributes {
    id
    name
    displayName
    sortOrder
    values {
      id
      value
      displayValue
      colorCode
      sortOrder
    }
  }

  flavors {
    id
    value
    displayValue
    colorCode
  }

  sizes {
    id
    value
    displayValue
  }
}
```

### React Components
```tsx
// components/VariantSelector.tsx
interface VariantSelectorProps {
  product: {
    id: string;
    name: string;
    variants: Variant[];
    variantAttributes: VariantAttribute[];
  };
  selectedVariant?: Variant;
  onVariantChange: (variant: Variant) => void;
}

export default function VariantSelector({ product, selectedVariant, onVariantChange }: VariantSelectorProps) {
  const [selectedAttributes, setSelectedAttributes] = useState<Record<string, string>>({});

  const handleAttributeChange = (attributeName: string, value: string) => {
    const newAttributes = { ...selectedAttributes, [attributeName]: value };
    setSelectedAttributes(newAttributes);

    // Find matching variant
    const matchingVariant = product.variants.find(variant => {
      return Object.entries(newAttributes).every(([attr, val]) => {
        return variant[attr] === val;
      });
    });

    if (matchingVariant) {
      onVariantChange(matchingVariant);
    }
  };

  return (
    <div className="space-y-4">
      <h3 className="font-semibold text-lg">Vyberte variantu</h3>

      {product.variantAttributes.map(attribute => (
        <div key={attribute.id} className="space-y-2">
          <label className="block text-sm font-medium">
            {attribute.displayName}
          </label>

          <div className="flex flex-wrap gap-2">
            {attribute.values.map(value => {
              const isSelected = selectedAttributes[attribute.name] === value.value;

              return (
                <button
                  key={value.id}
                  onClick={() => handleAttributeChange(attribute.name, value.value)}
                  className={`px-3 py-2 rounded-lg border transition-all ${
                    isSelected
                      ? 'border-blue-500 bg-blue-50 text-blue-700'
                      : 'border-gray-300 hover:border-gray-400'
                  }`}
                  style={value.colorCode ? { backgroundColor: value.colorCode + '20' } : {}}
                >
                  {value.colorCode && (
                    <span
                      className="inline-block w-4 h-4 rounded-full mr-2"
                      style={{ backgroundColor: value.colorCode }}
                    />
                  )}
                  {value.displayValue}
                </button>
              );
            })}
          </div>
        </div>
      ))}

      {selectedVariant && (
        <div className="mt-4 p-4 bg-green-50 rounded-lg">
          <h4 className="font-medium text-green-800">Vybraná varianta:</h4>
          <p className="text-green-700">{selectedVariant.variantDisplayName}</p>
          <p className="text-green-600 font-semibold">{selectedVariant.priceDecimal} CZK</p>
          {selectedVariant.variantSku && (
            <p className="text-sm text-green-600">SKU: {selectedVariant.variantSku}</p>
          )}
        </div>
      )}
    </div>
  );
}

// components/ProductVariantGrid.tsx
interface ProductVariantGridProps {
  product: {
    id: string;
    name: string;
    variants: Variant[];
  };
  onVariantSelect: (variant: Variant) => void;
}

export default function ProductVariantGrid({ product, onVariantSelect }: ProductVariantGridProps) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
      {product.variants.map(variant => (
        <div
          key={variant.id}
          onClick={() => onVariantSelect(variant)}
          className="border rounded-lg p-4 cursor-pointer hover:shadow-md transition-shadow"
        >
          <div className="space-y-2">
            <h4 className="font-medium text-sm">{variant.variantDisplayName}</h4>

            <div className="flex items-center gap-2">
              {variant.flavor && (
                <span className="px-2 py-1 bg-pink-100 text-pink-700 rounded text-xs">
                  {variant.flavor}
                </span>
              )}
              {variant.size && (
                <span className="px-2 py-1 bg-blue-100 text-blue-700 rounded text-xs">
                  {variant.size}
                </span>
              )}
            </div>

            <div className="flex justify-between items-center">
              <span className="font-bold text-green-600">
                {variant.priceDecimal} CZK
              </span>

              <span className={`text-xs px-2 py-1 rounded ${
                variant.inStock
                  ? 'bg-green-100 text-green-700'
                  : 'bg-red-100 text-red-700'
              }`}>
                {variant.inStock ? 'Skladem' : 'Vyprodáno'}
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
```

---

## 🧪 Testování

### GraphQL Testing
```graphql
# Test variant queries
query TestVariantQueries {
  products {
    id
    name
    isVariantParent
    variantCount

    variants {
      id
      variantDisplayName
      flavor
      size
      color
      priceDecimal
    }
  }

  variantAttributes {
    name
    displayName
    values {
      value
      displayValue
      colorCode
    }
  }

  flavors {
    value
    displayValue
    colorCode
  }
}

# Test vytvoření varianty
mutation TestCreateVariant {
  createProductVariant(
    parentProductId: "1"
    attributes: {
      flavor: "strawberry",
      size: "large"
    }
    priceCents: 25000
  ) {
    variant {
      id
      variantDisplayName
      variantSku
      flavor
      size
    }
    success
    errors
  }
}
```

### Console Testing
```ruby
# rails console
# Vytvoř parent product
parent = Product.create!(
  name: 'Popping Pearls',
  description: 'Bubble tea pearls',
  price_cents: 25000,
  is_variant_parent: true
)

# Vytvoř variantu
variant = parent.create_variant!(
  flavor: 'strawberry',
  size: 'large'
)

# Test variant methods
variant.variant_child?           # => true
variant.variant_display_name     # => "Popping Pearls - Jahoda, Velká"
variant.flavor                   # => "Jahoda"
variant.size                     # => "Velká"

# Test parent methods
parent.variant_parent?           # => true
parent.available_variants.count  # => 1
```

---

## 🔗 Related Documentation
- **[GraphQL API](./graphql.md)** - Complete API reference
- **[Bulk Pricing](./bulk-pricing.md)** - Quantity-based pricing
- **[Inventory System](./inventory.md)** - Stock management

---

*Dokumentace aktualizována: 18.6.2025*