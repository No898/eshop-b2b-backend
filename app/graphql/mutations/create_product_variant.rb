# frozen_string_literal: true

module Mutations
  class CreateProductVariant < BaseMutation
    include Mutations::Concerns::VariantProcessing

    description 'Vytvoří novou variantu produktu s atributy'

    argument :parent_product_id, ID, required: true, description: 'ID rodičovského produktu'
    argument :variant_attributes, GraphQL::Types::JSON, required: true,
                                                        description: 'Hash atributů varianty (flavor: 1, size: 2)'
    argument :price_cents, Integer, required: true, description: 'Cena v haléřích'
    argument :quantity, Integer, required: true, description: 'Množství na skladě'
    argument :description, String, required: false, description: 'Popis varianty'
    argument :weight_value, Float, required: false, description: 'Hmotnost hodnota'
    argument :weight_unit, String, required: false, description: 'Hmotnost jednotka'

    field :variant, Types::ProductType, null: true, description: 'Vytvořená varianta'
    field :errors, [String], null: false, description: 'Chyby při vytváření'

    def resolve(parent_product_id:, variant_attributes:, price_cents:, quantity:, **args)
      return authorization_error unless authorized?

      parent_product = find_parent_product(parent_product_id)
      return not_found_error unless parent_product

      validation_errors = validate_variant_creation(parent_product, variant_attributes)
      return validation_error(validation_errors) if validation_errors.any?

      create_variant_successfully(parent_product, variant_attributes, price_cents, quantity, args)
    rescue ActiveRecord::RecordInvalid => e
      { variant: nil, errors: e.record.errors.full_messages }
    rescue StandardError => e
      Rails.logger.error("Error creating product variant: #{e.message}")
      { variant: nil, errors: ['Failed to create variant'] }
    end

    private

    def authorized?
      context[:current_user]&.admin?
    end

    def authorization_error
      { variant: nil, errors: ['Unauthorized'] }
    end

    def find_parent_product(parent_product_id)
      Product.find_by(id: parent_product_id)
    end

    def not_found_error
      { variant: nil, errors: ['Parent product not found'] }
    end

    def validation_error(errors)
      { variant: nil, errors: errors }
    end

    def create_variant_successfully(parent_product, variant_attributes, price_cents, quantity, args)
      product_params = build_product_params(price_cents, quantity, args)
      variant = create_variant_with_attributes(parent_product, variant_attributes, product_params)
      log_variant_creation(variant, context[:current_user].id)

      { variant: variant, errors: [] }
    end

    def build_product_params(price_cents, quantity, args)
      {
        price_cents: price_cents,
        quantity: quantity,
        description: args[:description],
        weight_value: args[:weight_value],
        weight_unit: args[:weight_unit]
      }.compact
    end
  end
end
