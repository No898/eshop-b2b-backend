# 📦 Inventory Management System

Kompletní systém skladového hospodářství pro B2B e-commerce s real-time sledováním zásob a automatickou správou dostupnosti produktů.

## 📋 Obsah
- [🏗️ Architektura systému](#️-architektura-systému)
- [📊 Databázová struktura](#-databázová-struktura)
- [🎯 Business logika](#-business-logika)
- [🔧 GraphQL API](#-graphql-api)
- [💻 Frontend integrace](#-frontend-integrace)
- [🧪 Testování](#-testování)

---

## 🏗️ Architektura systému

### Účel systému
Inventory Management System poskytuje:
- **Real-time skladové zásoby** - okamžité sledování množství
- **Automatická dostupnost** - produkty se automaticky označí jako nedostupné při vyčerpání
- **Rezervace při objednávce** - dočasné rezervování produktů během checkout procesu
- **Bulk operations** - hromadné úpravy zásob
- **Audit trail** - historie všech změn skladových stavů

### Klíčové funkce
- ✅ **Thread-safe operace** - bezpečné paralelní úpravy zásob
- ✅ **Automatic availability** - automatické řízení dostupnosti
- ✅ **Stock validation** - kontrola dostupnosti při objednávce
- ✅ **Low stock alerts** - upozornění na nízké zásoby
- ✅ **GraphQL integration** - real-time inventory queries

---

## 📊 Databázová struktura

### Product Model Extension
```ruby
# app/models/product.rb - inventory fields
class Product < ApplicationRecord
  # Inventory fields (already in migration)
  # quantity: integer, default: 0, not null
  # min_stock_level: integer, default: 5, not null
  # track_inventory: boolean, default: true, not null

  # Scopes
  scope :in_stock, -> { where('quantity > 0') }
  scope :out_of_stock, -> { where(quantity: 0) }
  scope :low_stock, -> { where('quantity <= min_stock_level AND quantity > 0') }
  scope :available_for_sale, -> { where(available: true).in_stock }

  # Inventory methods
  def in_stock?
    track_inventory? ? quantity > 0 : true
  end

  def out_of_stock?
    track_inventory? ? quantity <= 0 : false
  end

  def low_stock?
    track_inventory? && quantity <= min_stock_level && quantity > 0
  end

  def stock_status
    return 'not_tracked' unless track_inventory?
    return 'out_of_stock' if quantity <= 0
    return 'low_stock' if quantity <= min_stock_level
    'in_stock'
  end

  def can_fulfill_quantity?(requested_quantity)
    return true unless track_inventory?
    quantity >= requested_quantity
  end

  # Thread-safe stock operations
  def reserve_stock!(quantity_to_reserve)
    return true unless track_inventory?

    with_lock do
      if can_fulfill_quantity?(quantity_to_reserve)
        update!(quantity: quantity - quantity_to_reserve)
        update_availability!
        true
      else
        false
      end
    end
  end

  def restore_stock!(quantity_to_restore)
    return true unless track_inventory?

    with_lock do
      update!(quantity: quantity + quantity_to_restore)
      update_availability!
      true
    end
  end

  def adjust_stock!(new_quantity, reason: nil)
    return true unless track_inventory?

    with_lock do
      old_quantity = quantity
      update!(quantity: new_quantity)
      update_availability!

      # Log inventory change
      log_inventory_change(old_quantity, new_quantity, reason)
      true
    end
  end

  private

  def update_availability!
    should_be_available = in_stock? && available_was != false
    update_column(:available, should_be_available) if available != should_be_available
  end

  def log_inventory_change(old_qty, new_qty, reason)
    Rails.logger.info({
      event: 'inventory_change',
      product_id: id,
      product_name: name,
      old_quantity: old_qty,
      new_quantity: new_qty,
      change: new_qty - old_qty,
      reason: reason,
      timestamp: Time.current
    }.to_json)
  end
end
```

### Database Migration
```ruby
# db/migrate/20250617221737_add_inventory_to_products.rb
class AddInventoryToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :quantity, :integer, default: 0, null: false
    add_column :products, :min_stock_level, :integer, default: 5, null: false
    add_column :products, :track_inventory, :boolean, default: true, null: false

    # Indexes for performance
    add_index :products, :quantity
    add_index :products, [:available, :quantity]
    add_index :products, [:track_inventory, :quantity]

    # Check constraints
    add_check_constraint :products, "quantity >= 0", name: "chk_products_quantity_non_negative"
    add_check_constraint :products, "min_stock_level >= 0", name: "chk_products_min_stock_level_non_negative"
  end
end
```

---

## 🎯 Business logika

### Order Integration
```ruby
# app/models/order.rb - inventory integration
class Order < ApplicationRecord
  before_create :reserve_inventory
  after_update :handle_inventory_on_status_change
  before_destroy :restore_inventory

  private

  def reserve_inventory
    order_items.each do |item|
      unless item.product.reserve_stock!(item.quantity)
        errors.add(:base, "Produkt #{item.product.name} není dostupný v požadovaném množství")
        throw :abort
      end
    end
  end

  def handle_inventory_on_status_change
    return unless saved_change_to_status?

    case status
    when 'cancelled'
      restore_inventory_for_cancelled_order
    when 'delivered'
      # Inventory already reserved, no action needed
      log_inventory_fulfillment
    end
  end

  def restore_inventory
    order_items.each do |item|
      item.product.restore_stock!(item.quantity)
    end
  end

  def restore_inventory_for_cancelled_order
    order_items.each do |item|
      item.product.restore_stock!(item.quantity)
    end
  end

  def log_inventory_fulfillment
    Rails.logger.info({
      event: 'order_fulfilled',
      order_id: id,
      items: order_items.map do |item|
        {
          product_id: item.product_id,
          product_name: item.product.name,
          quantity_sold: item.quantity
        }
      end
    }.to_json)
  end
end
```

### Inventory Service
```ruby
# app/services/inventory_service.rb
class InventoryService
  class InsufficientStockError < StandardError; end

  def self.check_availability(items)
    items.each do |item|
      product = Product.find(item[:product_id])
      requested_quantity = item[:quantity]

      unless product.can_fulfill_quantity?(requested_quantity)
        raise InsufficientStockError,
              "Produkt '#{product.name}' není dostupný v množství #{requested_quantity}. " \
              "Dostupné množství: #{product.quantity}"
      end
    end
  end

  def self.bulk_adjust_stock(adjustments)
    ActiveRecord::Base.transaction do
      adjustments.each do |adjustment|
        product = Product.find(adjustment[:product_id])
        new_quantity = adjustment[:quantity]
        reason = adjustment[:reason] || 'bulk_adjustment'

        product.adjust_stock!(new_quantity, reason: reason)
      end
    end
  end

  def self.get_low_stock_products(limit: 50)
    Product.low_stock
           .includes(:price_tiers)
           .order(:quantity)
           .limit(limit)
  end

  def self.get_inventory_report
    {
      total_products: Product.count,
      in_stock_products: Product.in_stock.count,
      out_of_stock_products: Product.out_of_stock.count,
      low_stock_products: Product.low_stock.count,
      total_inventory_value: calculate_total_inventory_value,
      low_stock_alerts: get_low_stock_products(limit: 10)
    }
  end

  private

  def self.calculate_total_inventory_value
    Product.in_stock.sum('quantity * price_cents') / 100.0
  end
end
```

---

## 🔧 GraphQL API

### ProductType Extension
```ruby
# app/graphql/types/product_type.rb - inventory fields
field :quantity, Integer, null: false, description: 'Skladové množství'
field :min_stock_level, Integer, null: false, description: 'Minimální úroveň zásob'
field :track_inventory, Boolean, null: false, description: 'Sledovat zásoby?'

# Computed inventory fields
field :in_stock, Boolean, null: false, description: 'Je skladem?'
field :out_of_stock, Boolean, null: false, description: 'Není skladem?'
field :low_stock, Boolean, null: false, description: 'Nízké zásoby?'
field :stock_status, String, null: false, description: 'Stav zásob'

field :can_fulfill_quantity, Boolean, null: false do
  argument :quantity, Integer, required: true
  description 'Může splnit požadované množství?'
end

# Resolver methods
def in_stock
  object.in_stock?
end

def stock_status
  object.stock_status
end

def can_fulfill_quantity(quantity:)
  object.can_fulfill_quantity?(quantity)
end
```

### Inventory Queries
```graphql
# Produkty s inventory informacemi
query GetProductsWithInventory {
  products {
    id
    name
    priceDecimal

    # Inventory info
    quantity
    minStockLevel
    trackInventory
    inStock
    outOfStock
    lowStock
    stockStatus

    # Check specific quantity
    canFulfillQuantity(quantity: 10)
  }
}

# Low stock products
query GetLowStockProducts {
  productsLowStock {
    id
    name
    quantity
    minStockLevel
    priceDecimal
  }
}
```

### Inventory Mutations (Admin Only)
```ruby
# app/graphql/mutations/adjust_product_stock.rb
module Mutations
  class AdjustProductStock < BaseMutation
    description 'Upraví skladové zásoby produktu (pouze admin)'

    argument :product_id, ID, required: true
    argument :quantity, Integer, required: true
    argument :reason, String, required: false

    field :product, Types::ProductType, null: true
    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(product_id:, quantity:, reason: nil)
      authorize_admin!

      product = Product.find(product_id)

      if product.adjust_stock!(quantity, reason: reason)
        {
          product: product.reload,
          success: true,
          errors: []
        }
      else
        {
          product: nil,
          success: false,
          errors: product.errors.full_messages
        }
      end
    rescue ActiveRecord::RecordNotFound
      {
        product: nil,
        success: false,
        errors: ['Produkt nenalezen']
      }
    end
  end
end

# app/graphql/mutations/bulk_adjust_stock.rb
module Mutations
  class BulkAdjustStock < BaseMutation
    description 'Hromadná úprava skladových zásob (pouze admin)'

    argument :adjustments, [Types::StockAdjustmentInputType], required: true

    field :success, Boolean, null: false
    field :processed_count, Integer, null: false
    field :errors, [String], null: false

    def resolve(adjustments:)
      authorize_admin!

      InventoryService.bulk_adjust_stock(adjustments)

      {
        success: true,
        processed_count: adjustments.length,
        errors: []
      }
    rescue => error
      {
        success: false,
        processed_count: 0,
        errors: [error.message]
      }
    end
  end
end
```

---

## 💻 Frontend integrace

### React Components
```tsx
// components/InventoryStatus.tsx
interface InventoryStatusProps {
  product: {
    id: string;
    name: string;
    quantity: number;
    stockStatus: 'in_stock' | 'low_stock' | 'out_of_stock' | 'not_tracked';
    trackInventory: boolean;
  };
}

export default function InventoryStatus({ product }: InventoryStatusProps) {
  if (!product.trackInventory) {
    return (
      <span className="text-gray-500 text-sm">
        📦 Zásoby nesledovány
      </span>
    );
  }

  const getStatusConfig = () => {
    switch (product.stockStatus) {
      case 'in_stock':
        return {
          icon: '✅',
          text: `Skladem (${product.quantity} ks)`,
          className: 'text-green-600'
        };
      case 'low_stock':
        return {
          icon: '⚠️',
          text: `Nízké zásoby (${product.quantity} ks)`,
          className: 'text-yellow-600'
        };
      case 'out_of_stock':
        return {
          icon: '❌',
          text: 'Vyprodáno',
          className: 'text-red-600'
        };
      default:
        return {
          icon: '❓',
          text: 'Neznámý stav',
          className: 'text-gray-500'
        };
    }
  };

  const config = getStatusConfig();

  return (
    <span className={`text-sm font-medium ${config.className}`}>
      {config.icon} {config.text}
    </span>
  );
}

// components/QuantitySelector.tsx - with inventory check
interface QuantitySelectorProps {
  product: {
    id: string;
    quantity: number;
    trackInventory: boolean;
  };
  value: number;
  onChange: (quantity: number) => void;
}

export default function QuantitySelector({ product, value, onChange }: QuantitySelectorProps) {
  const maxQuantity = product.trackInventory ? product.quantity : 999;

  const handleIncrease = () => {
    if (value < maxQuantity) {
      onChange(value + 1);
    }
  };

  const handleDecrease = () => {
    if (value > 1) {
      onChange(value - 1);
    }
  };

  return (
    <div className="flex items-center gap-2">
      <button
        onClick={handleDecrease}
        disabled={value <= 1}
        className="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-50"
      >
        -
      </button>

      <input
        type="number"
        value={value}
        onChange={(e) => onChange(parseInt(e.target.value) || 1)}
        min="1"
        max={maxQuantity}
        className="w-16 px-2 py-1 border rounded text-center"
      />

      <button
        onClick={handleIncrease}
        disabled={value >= maxQuantity}
        className="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-50"
      >
        +
      </button>

      {product.trackInventory && (
        <span className="text-sm text-gray-500">
          / {maxQuantity} dostupných
        </span>
      )}
    </div>
  );
}
```

### Admin Inventory Management
```tsx
// components/admin/InventoryManager.tsx
export default function InventoryManager() {
  const [adjustmentData, setAdjustmentData] = useState({
    productId: '',
    quantity: 0,
    reason: ''
  });

  const [adjustStockMutation] = useMutation(ADJUST_PRODUCT_STOCK);

  const handleAdjustStock = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const result = await adjustStockMutation({
        variables: adjustmentData
      });

      if (result.data.adjustProductStock.success) {
        alert('Zásoby byly úspěšně upraveny');
        setAdjustmentData({ productId: '', quantity: 0, reason: '' });
      } else {
        alert('Chyba: ' + result.data.adjustProductStock.errors.join(', '));
      }
    } catch (error) {
      alert('Chyba při úpravě zásob');
    }
  };

  return (
    <div className="max-w-md mx-auto bg-white p-6 rounded-lg shadow">
      <h2 className="text-xl font-bold mb-4">Správa skladových zásob</h2>

      <form onSubmit={handleAdjustStock} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">
            ID produktu
          </label>
          <input
            type="text"
            value={adjustmentData.productId}
            onChange={(e) => setAdjustmentData(prev => ({ ...prev, productId: e.target.value }))}
            className="w-full px-3 py-2 border rounded-lg"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">
            Nové množství
          </label>
          <input
            type="number"
            value={adjustmentData.quantity}
            onChange={(e) => setAdjustmentData(prev => ({ ...prev, quantity: parseInt(e.target.value) || 0 }))}
            className="w-full px-3 py-2 border rounded-lg"
            min="0"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">
            Důvod úpravy
          </label>
          <select
            value={adjustmentData.reason}
            onChange={(e) => setAdjustmentData(prev => ({ ...prev, reason: e.target.value }))}
            className="w-full px-3 py-2 border rounded-lg"
          >
            <option value="">Vyberte důvod</option>
            <option value="stock_take">Inventura</option>
            <option value="damage">Poškození</option>
            <option value="theft">Krádež</option>
            <option value="supplier_delivery">Dodávka od dodavatele</option>
            <option value="manual_adjustment">Ruční úprava</option>
          </select>
        </div>

        <button
          type="submit"
          className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          Upravit zásoby
        </button>
      </form>
    </div>
  );
}
```

---

## 🧪 Testování

### GraphQL Testing
```graphql
# Test inventory queries
query TestInventoryQueries {
  products {
    id
    name
    quantity
    stockStatus
    inStock
    lowStock
    canFulfillQuantity(quantity: 5)
  }

  productsLowStock {
    id
    name
    quantity
    minStockLevel
  }
}

# Test stock adjustment (admin only)
mutation TestAdjustStock {
  adjustProductStock(
    productId: "1"
    quantity: 100
    reason: "stock_take"
  ) {
    product {
      id
      quantity
      stockStatus
    }
    success
    errors
  }
}
```

### Console Testing
```ruby
# rails console
product = Product.first

# Test inventory methods
product.in_stock?           # => true/false
product.stock_status        # => "in_stock", "low_stock", "out_of_stock"
product.can_fulfill_quantity?(10)  # => true/false

# Test stock operations
product.reserve_stock!(5)   # Reserve 5 units
product.restore_stock!(2)   # Restore 2 units
product.adjust_stock!(50, reason: 'inventory_adjustment')

# Test scopes
Product.in_stock.count
Product.low_stock.pluck(:name, :quantity)
Product.out_of_stock.count
```

---

## 🔗 Related Documentation
- **[GraphQL API](./graphql.md)** - Complete API reference
- **[Product Variants](./variants.md)** - Product variant system
- **[Bulk Pricing](./bulk-pricing.md)** - Quantity-based pricing

---

*Dokumentace aktualizována: 18.6.2025*