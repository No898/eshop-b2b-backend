# frozen_string_literal: true

module ProductVariants
  extend ActiveSupport::Concern

  included do
    # Product variants relationships
    belongs_to :parent_product, class_name: 'Product', optional: true
    has_many :variants, class_name: 'Product', foreign_key: 'parent_product_id', dependent: :destroy,
                        inverse_of: :parent_product
    has_many :product_variant_attributes, dependent: :destroy
    has_many :variant_attributes, through: :product_variant_attributes
    has_many :variant_attribute_values, through: :product_variant_attributes

    # Validations
    validates :variant_sku, uniqueness: { allow_nil: true }, length: { maximum: 50 }
    validates :variant_sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

    # Scopes
    scope :variant_parents, -> { where(is_variant_parent: true) }
    scope :variant_children, -> { where.not(parent_product_id: nil) }
    scope :standalone_products, -> { where(is_variant_parent: false, parent_product_id: nil) }
    scope :available_variants, -> { where(available: true) }
    scope :in_stock_variants, -> { where('quantity > 0') }
    scope :sorted_variants, -> { order(:variant_sort_order, :name) }
  end

  # Instance methods
  def variant_parent?
    is_variant_parent?
  end

  def variant_child?
    parent_product_id.present?
  end

  def standalone_product?
    !variant_parent? && !variant_child?
  end

  def variants?
    variant_parent? && variants.any?
  end

  def variant_display_name
    return name unless variant_child?

    attribute_names = variant_attribute_values.includes(:variant_attribute)
                                              .map { |vav| "#{vav.variant_attribute.name}: #{vav.value}" }
    return name if attribute_names.empty?

    "#{parent_product.name} (#{attribute_names.join(', ')})"
  end

  # Attribute-specific methods
  def flavor
    get_variant_attribute_value('flavor')
  end

  def size
    get_variant_attribute_value('size')
  end

  def color
    get_variant_attribute_value('color')
  end

  def flavor?
    flavor.present?
  end

  def size?
    size.present?
  end

  def color?
    color.present?
  end

  private

  def get_variant_attribute_value(attribute_name)
    variant_attribute_values.joins(:variant_attribute)
                            .find_by(variant_attributes: { name: attribute_name })
  end
end
