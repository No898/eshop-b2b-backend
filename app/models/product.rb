# frozen_string_literal: true

class Product < ApplicationRecord
  # ASSOCIATIONS
  has_many :order_items, dependent: :restrict_with_error
  has_many_attached :images

  # VALIDATIONS - Basic product info
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[CZK EUR] }

  # VALIDATIONS - Inventory management
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :low_stock_threshold, presence: true, numericality: { greater_than: 0 }

  # VALIDATIONS - Product specifications
  validates :weight_value, numericality: { greater_than: 0 }, allow_nil: true
  validates :weight_unit, inclusion: { in: %w[kg g l ml] }, allow_nil: true
  validates :ingredients, length: { maximum: 5000 }, allow_blank: true

  # CUSTOM VALIDATION - Weight consistency (both or neither)
  validate :weight_fields_consistency

  # SCOPES - Product filtering
  scope :available, -> { where(available: true) }
  scope :in_stock, -> { where('quantity > 0') }
  scope :out_of_stock, -> { where(quantity: 0) }
  scope :low_stock, -> { where('quantity <= low_stock_threshold AND quantity > 0') }
  scope :with_sufficient_stock, ->(required_quantity) { where(quantity: required_quantity..) }

  # CALLBACKS - Inventory tracking
  before_update :log_stock_change, if: :quantity_changed?
  after_update :notify_low_stock, if: :low_stock?

  # BUSINESS METHODS - Pricing
  def price
    price_cents / 100.0
  end

  def formatted_price
    "#{price} #{currency}"
  end

  # BUSINESS METHODS - Product specifications
  def has_weight_info?
    weight_value.present? && weight_unit.present?
  end

  def formatted_weight
    return nil unless has_weight_info?

    "#{weight_value.to_f} #{weight_unit}"
  end

  def has_ingredients?
    ingredients.present?
  end

  def weight_in_grams
    return nil unless has_weight_info?

    case weight_unit
    when 'kg' then weight_value * 1000
    when 'g'  then weight_value
    when 'l'  then weight_value * 1000  # Assuming 1l = 1000g for liquids
    when 'ml' then weight_value         # Assuming 1ml = 1g for syrups
    end
  end

  def is_liquid?
    weight_unit.in?(%w[l ml])
  end

  def is_solid?
    weight_unit.in?(%w[kg g])
  end

  # BUSINESS METHODS - Inventory management
  def in_stock?
    quantity.positive?
  end

  def out_of_stock?
    quantity.zero?
  end

  def low_stock?
    quantity <= low_stock_threshold && quantity.positive?
  end

  def sufficient_stock?(required_quantity)
    quantity >= required_quantity
  end

  def can_fulfill_order?(requested_quantity)
    available? && sufficient_stock?(requested_quantity)
  end

  # BUSINESS METHODS - Stock operations
  def reserve_stock!(quantity_to_reserve)
    raise InsufficientStockError.new(self, quantity_to_reserve) unless sufficient_stock?(quantity_to_reserve)

    with_lock do
      # THREAD SAFETY: Re-check stock after acquiring lock
      raise InsufficientStockError.new(self, quantity_to_reserve) unless sufficient_stock?(quantity_to_reserve)

      decrement!(:quantity, quantity_to_reserve)
      Rails.logger.info("Stock reserved: Product #{id}, quantity: #{quantity_to_reserve}, remaining: #{quantity}")
    end
  end

  def release_stock!(quantity_to_release)
    increment!(:quantity, quantity_to_release)
    Rails.logger.info("Stock released: Product #{id}, quantity: #{quantity_to_release}, new total: #{quantity}")
  end

  def update_stock!(new_quantity, reason: nil)
    old_quantity = quantity
    update!(quantity: new_quantity)
    Rails.logger.info("Stock updated: Product #{id}, from #{old_quantity} to #{new_quantity}, reason: #{reason}")
  end

  private

  def log_stock_change
    return unless quantity_changed?

    Rails.logger.info(
      "Stock change detected: Product #{id} (#{name}) - " \
      "from #{quantity_was} to #{quantity}"
    )
  end

  def notify_low_stock
    Rails.logger.warn(
      "LOW STOCK ALERT: Product #{id} (#{name}) - " \
      "current stock: #{quantity}, threshold: #{low_stock_threshold}"
    )
    # TODO: Implement email/webhook notification for low stock
  end

  def weight_fields_consistency
    # BUSINESS RULE: Weight value and unit must be both present or both nil
    if weight_value.present? && weight_unit.blank?
      errors.add(:weight_unit, 'je vyžadována když je zadána hmotnost/objem')
    elsif weight_unit.present? && weight_value.blank?
      errors.add(:weight_value, 'je vyžadována když je zadána jednotka')
    end
  end
end

# CUSTOM EXCEPTIONS
class InsufficientStockError < StandardError
  attr_reader :product, :requested_quantity

  def initialize(product, requested_quantity)
    @product = product
    @requested_quantity = requested_quantity
    super("Insufficient stock for product '#{product.name}' (ID: #{product.id}). " \
          "Requested: #{requested_quantity}, Available: #{product.quantity}")
  end
end
