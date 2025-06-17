# frozen_string_literal: true

module VariantProcessing
  extend ActiveSupport::Concern

  private

  def validate_variant_creation(parent_product, variant_attributes)
    errors = []
    return ['Parent product must be a variant parent'] unless parent_product.variant_parent?

    validate_each_attribute(variant_attributes, errors)
    errors
  end

  def validate_each_attribute(variant_attributes, errors)
    variant_attributes.each do |attr_name, value_id|
      attribute = find_variant_attribute(attr_name, errors)
      next unless attribute

      validate_attribute_value(attribute, value_id, attr_name, errors)
    end
  end

  def find_variant_attribute(attr_name, errors)
    attribute = VariantAttribute.find_by(name: attr_name.to_s)
    errors << "Variant attribute '#{attr_name}' not found" unless attribute
    attribute
  end

  def validate_attribute_value(attribute, value_id, attr_name, errors)
    return if attribute.variant_attribute_values.exists?(id: value_id)

    errors << "Variant attribute value ID #{value_id} not found for attribute '#{attr_name}'"
  end

  def create_variant_with_attributes(parent_product, variant_attributes, product_params)
    variant = parent_product.create_variant!(variant_attributes, **product_params)

    # Create default bulk pricing if parent has it
    create_variant_bulk_pricing(variant, product_params[:price_cents]) if parent_product.bulk_pricing?

    variant
  end

  def create_variant_bulk_pricing(variant, price_cents)
    bulk_pricing_tiers = build_bulk_pricing_tiers(price_cents)
    variant.price_tiers.create!(bulk_pricing_tiers)
  end

  def build_bulk_pricing_tiers(price_cents)
    [
      build_tier_1bal(price_cents),
      build_tier_10bal(price_cents)
    ]
  end

  def build_tier_1bal(price_cents)
    {
      tier_name: '1bal',
      min_quantity: 12,
      max_quantity: 119,
      price_cents: (price_cents * 0.88).round,
      description: 'Balení 12 kusů - úspora 12%'
    }
  end

  def build_tier_10bal(price_cents)
    {
      tier_name: '10bal',
      min_quantity: 120,
      max_quantity: nil,
      price_cents: (price_cents * 0.80).round,
      description: 'Kartón 120 kusů - úspora 20%'
    }
  end

  def log_variant_creation(variant, user_id)
    Rails.logger.info(
      "Product variant created: #{variant.id} (#{variant.variant_display_name}) " \
      "by user #{user_id}"
    )
  end
end
