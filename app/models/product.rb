# frozen_string_literal: true

class Product < ApplicationRecord
  include ProductSpecifications
  include ProductVariants

  # Associations
  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items
  has_many :price_tiers, class_name: 'ProductPriceTier', dependent: :destroy
  has_many_attached :images

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :description, length: { maximum: 2000 }
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: { allow_blank: true }
  validates :variant_sku, uniqueness: { allow_blank: true }

  # Variant validations
  validates :parent_product_id, absence: true, if: :is_variant_parent?
  validates :parent_product_id, presence: true, if: :variant_child?
  validates :is_variant_parent, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :in_stock, -> { where('quantity > 0') }
  scope :with_images, -> { joins(:images_attachments) }
  scope :with_bulk_pricing, -> { joins(:price_tiers).distinct }
  scope :with_sufficient_stock, ->(required_quantity) { where(quantity: required_quantity..) }

  # Callbacks
  before_save :ensure_variant_consistency
  after_create :create_default_bulk_pricing, if: :should_create_default_pricing?

  # PRICING METHODS
  def price_decimal
    price_cents / 100.0
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

  def reserve_stock!(quantity_to_reserve)
    if quantity < quantity_to_reserve
      raise InsufficientStockError, "Insufficient stock. Available: #{quantity}, requested: #{quantity_to_reserve}"
    end

    update!(quantity: quantity - quantity_to_reserve)
  end

  def release_stock!(quantity_to_release)
    update!(quantity: quantity + quantity_to_release)
  end

  # IMAGE METHODS
  def images?
    images.attached?
  end

  def primary_image
    images.first
  end

  private

  def ensure_variant_consistency
    if is_variant_parent? && parent_product_id.present?
      errors.add(:parent_product_id, 'cannot be set for variant parent')
      throw :abort
    end

    return unless !is_variant_parent? && parent_product_id.blank? && variants.exists?

    errors.add(:is_variant_parent, 'must be true if product has variants')
    throw :abort
  end

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

  class InsufficientStockError < StandardError; end
end
