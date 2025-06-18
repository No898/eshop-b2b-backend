# frozen_string_literal: true

module ProductVariantCreation
  extend ActiveSupport::Concern

  def create_variant!(variant_attributes, product_params = {})
    transaction do
      variant = create_variant_product(variant_attributes, product_params)
      create_variant_associations(variant, variant_attributes)
      variant
    end
  end

  private

  def generate_variant_name(variant_attributes)
    attribute_names = variant_attributes.values.map do |value_id|
      value = VariantAttributeValue.find(value_id)
      value.display_value
    end

    "#{name} - #{attribute_names.join(', ')}"
  end

  def generate_variant_sku(variant_attributes)
    base_sku = name.parameterize[0..10]
    attribute_codes = variant_attributes.map do |attr_name, value_id|
      value = VariantAttributeValue.find(value_id)
      "#{attr_name[0]}#{value.value[0..2]}"
    end.join('-')

    "#{base_sku}-#{attribute_codes}".upcase
  end

  def create_variant_product(variant_attributes, product_params)
    variant_name = generate_variant_name(variant_attributes)
    sku = product_params[:variant_sku] || generate_variant_sku(variant_attributes)
    sort_order = product_params[:variant_sort_order] || (variants.count + 1)

    variants.create!(product_params.merge(
                       name: variant_name,
                       is_variant_parent: false,
                       available: true,
                       variant_sku: sku,
                       variant_sort_order: sort_order
                     ))
  end

  def create_variant_associations(variant, variant_attributes)
    variant_attributes.each_value do |value_id|
      variant_attribute_value = VariantAttributeValue.find(value_id)
      variant.product_variant_attributes.create!(
        variant_attribute_value: variant_attribute_value
      )
    end
  end
end
