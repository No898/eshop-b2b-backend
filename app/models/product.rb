# frozen_string_literal: true

class Product < ApplicationRecord
  include ProductSpecifications
  include ProductVariants
  include ProductPricing
  include ProductInventory
  include ProductImages

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

  class InsufficientStockError < StandardError; end
end
