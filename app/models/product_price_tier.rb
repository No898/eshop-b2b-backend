# frozen_string_literal: true

class ProductPriceTier < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :product

  # ENUMS
  enum :tier_name, {
    '1ks' => '1ks',        # Jednotlivé kusy
    '1bal' => '1bal',      # Jedno balení (např. 12 kusů)
    '10bal' => '10bal',    # Kartón (10 balení = 120 kusů)
    'custom' => 'custom'   # Vlastní množstevní slevy
  }

  # VALIDATIONS
  validates :tier_name, presence: true, inclusion: { in: tier_names.keys }
  validates :min_quantity, presence: true, numericality: { greater_than: 0 }
  validates :max_quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[CZK EUR] }
  validates :priority, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Custom validations
  validate :max_quantity_greater_than_min
  validate :unique_tier_per_product

  # SCOPES
  scope :active, -> { where(active: true) }
  scope :for_quantity, lambda { |quantity|
    where('min_quantity <= ? AND (max_quantity IS NULL OR max_quantity >= ?)', quantity, quantity)
  }
  scope :ordered_by_priority, -> { order(:priority, :min_quantity) }

  # CALLBACKS
  before_validation :set_default_priority, if: :new_record?

  # BUSINESS METHODS
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

  # CLASS METHODS
  def self.best_price_for_quantity(product_id, quantity)
    where(product_id: product_id)
      .active
      .for_quantity(quantity)
      .order(:price_cents)
      .first
  end

  private

  def max_quantity_greater_than_min
    return unless max_quantity.present? && min_quantity.present?
    return if max_quantity >= min_quantity

    errors.add(:max_quantity, 'musí být větší nebo rovno min_quantity')
  end

  def unique_tier_per_product
    return unless product_id.present? && tier_name.present?

    existing = self.class.where(
      product_id: product_id,
      tier_name: tier_name
    ).where.not(id: id)

    errors.add(:tier_name, 'již existuje pro tento produkt') if existing.exists?
  end

  def set_default_priority
    return if priority.present?

    # Nastavíme prioritu podle tier_name
    self.priority = case tier_name
                    when '1ks' then 0 # Nejvyšší priorita
                    when '1bal' then 10
                    when '10bal' then 20
                    when 'custom' then 50 # Nejnižší priorita
                    else 100
                    end
  end
end
