# frozen_string_literal: true

module ProductInventory
  extend ActiveSupport::Concern

  # STOCK METHODS
  def in_stock?
    quantity.positive?
  end

  def low_stock?(threshold = 10)
    quantity <= threshold && quantity.positive?
  end

  def out_of_stock?
    quantity <= 0
  end

  def can_fulfill_order?(requested_quantity)
    quantity >= requested_quantity
  end

  def reserve_stock!(quantity_to_reserve)
    if quantity < quantity_to_reserve
      raise Product::InsufficientStockError,
            "Insufficient stock. Available: #{quantity}, requested: #{quantity_to_reserve}"
    end

    update!(quantity: quantity - quantity_to_reserve)
  end

  def release_stock!(quantity_to_release)
    update!(quantity: quantity + quantity_to_release)
  end
end
