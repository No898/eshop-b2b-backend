# frozen_string_literal: true

class VariantAttributeValue < ApplicationRecord
  # Associations
  belongs_to :variant_attribute
  has_many :product_variant_attributes, dependent: :destroy
  has_many :products, through: :product_variant_attributes

  # Validations
  validates :value, presence: true,
                    length: { minimum: 1, maximum: 100 },
                    uniqueness: { scope: :variant_attribute_id, case_sensitive: false }

  validates :display_value, presence: true,
                            length: { minimum: 1, maximum: 100 }

  validates :color_code, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: :invalid_hex_color },
                         allow_blank: true

  validates :sort_order, presence: true,
                         numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :normalize_values
  before_validation :set_default_display_value

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :display_value) }
  scope :for_attribute, lambda { |attribute_name|
    joins(:variant_attribute).where(variant_attributes: { name: attribute_name })
  }
  scope :with_color, -> { where.not(color_code: [nil, '']) }

  # Delegations
  delegate :name, :display_name, to: :variant_attribute, prefix: :attribute

  # Class methods
  def self.flavors
    for_attribute('flavor').active.ordered
  end

  def self.sizes
    for_attribute('size').active.ordered
  end

  def self.colors
    for_attribute('color').active.ordered
  end

  def self.create_flavor!(value, display_value, color_code: nil, description: nil)
    flavor_attr = VariantAttribute.find_or_create_flavor!
    create!(
      variant_attribute: flavor_attr,
      value: value,
      display_value: display_value,
      color_code: color_code,
      description: description
    )
  end

  def self.create_size!(value, display_value, description: nil)
    size_attr = VariantAttribute.find_or_create_size!
    create!(
      variant_attribute: size_attr,
      value: value,
      display_value: display_value,
      description: description
    )
  end

  # Instance methods
  def flavor?
    variant_attribute.attribute_flavor?
  end

  def size?
    variant_attribute.attribute_size?
  end

  def color?
    color_code.present?
  end

  delegate :count, to: :products, prefix: true

  def can_be_deleted?
    products.empty?
  end

  def deactivate!
    update!(active: false)
  end

  def to_s
    display_value
  end

  # For frontend display
  def display_with_attribute
    "#{attribute_display_name}: #{display_value}"
  end

  # For GraphQL
  def graphql_representation
    {
      id: id,
      attribute_name: variant_attribute.name,
      attribute_display_name: variant_attribute.display_name,
      value: value,
      display_value: display_value,
      color_code: color_code,
      description: description
    }
  end

  private

  def normalize_values
    self.value = value.to_s.downcase.strip if value.present?
    self.display_value = display_value.to_s.strip if display_value.present?
    self.color_code = color_code.to_s.upcase if color_code.present?
  end

  def set_default_display_value
    self.display_value = value.to_s.humanize if display_value.blank? && value.present?
  end
end
