# frozen_string_literal: true

class VariantAttribute < ApplicationRecord
  # Associations
  has_many :variant_attribute_values, dependent: :destroy
  has_many :product_variant_attributes, through: :variant_attribute_values
  has_many :products, through: :product_variant_attributes

  # Validations
  validates :name, presence: true,
                   uniqueness: { case_sensitive: false },
                   length: { minimum: 2, maximum: 50 },
                   format: { with: /\A[a-z_]+\z/, message: :invalid_attribute_name }

  validates :display_name, presence: true,
                           length: { minimum: 2, maximum: 100 }

  validates :sort_order, presence: true,
                         numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :display_name) }
  scope :with_attribute_values, -> { includes(:variant_attribute_values) }

  # Enums for common attribute types
  enum :name, {
    flavor: 'flavor',
    size: 'size',
    color: 'color',
    material: 'material',
    capacity: 'capacity'
  }, prefix: :attribute

  # Class methods
  def self.find_or_create_flavor!
    find_or_create_by!(name: 'flavor') do |attr|
      attr.display_name = 'Příchuť'
      attr.description = 'Chuťová varianta produktu'
      attr.sort_order = 1
    end
  end

  def self.find_or_create_size!
    find_or_create_by!(name: 'size') do |attr|
      attr.display_name = 'Velikost'
      attr.description = 'Velikostní varianta produktu'
      attr.sort_order = 2
    end
  end

  def self.find_or_create_color!
    find_or_create_by!(name: 'color') do |attr|
      attr.display_name = 'Barva'
      attr.description = 'Barevná varianta produktu'
      attr.sort_order = 3
    end
  end

  # Instance methods
  def active_values
    variant_attribute_values.active.ordered
  end

  def values_count
    variant_attribute_values.active.count
  end

  def can_be_deleted?
    products.empty?
  end

  def deactivate!
    transaction do
      variant_attribute_values.find_each { |value| value.update!(active: false) }
      update!(active: false)
    end
  end

  def to_s
    display_name
  end

  # For GraphQL enum generation
  def graphql_enum_values
    active_values.pluck(:value, :display_value).map do |value, display|
      { value: value.upcase, description: display }
    end
  end

  private

  def normalize_name
    self.name = name.to_s.downcase.strip if name.present?
  end
end
