# frozen_string_literal: true

class ProductVariantAttribute < ApplicationRecord
  # Associations
  belongs_to :product
  belongs_to :variant_attribute_value

  # Validations
  validates :product_id, uniqueness: {
    scope: :variant_attribute_value_id,
    message: :duplicate_attribute_value
  }

  # Delegations
  delegate :variant_attribute, to: :variant_attribute_value
  delegate :name, :display_name, to: :variant_attribute, prefix: :attribute
  delegate :value, :display_value, :color_code, to: :variant_attribute_value

  # Scopes
  scope :for_attribute, lambda { |attribute_name|
    joins(variant_attribute_value: :variant_attribute)
      .where(variant_attributes: { name: attribute_name })
  }

  scope :flavors, -> { for_attribute('flavor') }
  scope :sizes, -> { for_attribute('size') }
  scope :colors, -> { for_attribute('color') }

  # Class methods
  def self.group_by_attribute
    includes(variant_attribute_value: :variant_attribute)
      .group_by(&:attribute_name)
  end

  # Instance methods
  def flavor?
    variant_attribute.attribute_flavor?
  end

  def size?
    variant_attribute.attribute_size?
  end

  def color?
    variant_attribute.attribute_color?
  end

  def to_s
    "#{product.name} - #{display_value}"
  end

  # For GraphQL representation
  def graphql_representation
    {
      attribute_name: attribute_name,
      attribute_display_name: attribute_display_name,
      value: value,
      display_value: display_value,
      color_code: color_code
    }
  end
end
