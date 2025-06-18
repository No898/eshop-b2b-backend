# frozen_string_literal: true

module ProductPricing
  extend ActiveSupport::Concern

  # PRICING METHODS
  def price_decimal
    price_cents / 100.0
  end

  def formatted_price
    "#{price_decimal} #{currency}"
  end

  def price_for_quantity(quantity)
    return price_decimal if quantity <= 1

    applicable_tier = price_tiers.active
                                 .where(min_quantity: ..quantity)
                                 .where('max_quantity IS NULL OR max_quantity >= ?', quantity)
                                 .order(:min_quantity)
                                 .last

    applicable_tier&.price_decimal || price_decimal
  end

  def bulk_savings_for_quantity(quantity)
    base_price = price_decimal
    bulk_price = price_for_quantity(quantity)
    return 0 if base_price == bulk_price

    ((base_price - bulk_price) / base_price * 100).round(1)
  end

  def bulk_pricing?
    price_tiers.exists?
  end

  def available_price_tiers
    price_tiers.active.ordered_by_priority
  end

  def price
    price_decimal
  end

  private

  def should_create_default_pricing?
    price_cents.present? && price_tiers.empty?
  end

  def create_default_bulk_pricing
    # 12% sleva pro 12+ kusů
    price_tiers.create!(
      tier_name: '1bal',
      min_quantity: 12,
      max_quantity: 119,
      price_cents: (price_cents * 0.88).round,
      description: 'Balení 12 kusů - úspora 12%'
    )

    # 20% sleva pro 120+ kusů
    price_tiers.create!(
      tier_name: '10bal',
      min_quantity: 120,
      max_quantity: nil,
      price_cents: (price_cents * 0.80).round,
      description: 'Kartón 120 kusů - úspora 20%'
    )
  end
end
