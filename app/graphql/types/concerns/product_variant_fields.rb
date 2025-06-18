# frozen_string_literal: true

module Types
  module ProductVariantFields
    extend ActiveSupport::Concern

    included do
      # PRODUCT VARIANTS - Varianty produktu
      field :is_variant_parent, GraphQL::Types::Boolean, null: false, description: 'Je produkt rodičovský pro varianty?'
      field :is_variant_child, GraphQL::Types::Boolean, null: false,
                                                        description: 'Je produkt variantou jiného produktu?'
      field :is_standalone_product, GraphQL::Types::Boolean, null: false,
                                                             description: 'Je produkt samostatný?'
      field :parent_product, Types::ProductType, null: true, description: 'Rodičovský produkt (pokud je varianta)'
      field :variants, [Types::ProductType], null: false, description: 'Varianty tohoto produktu'
      field :available_variants, [Types::ProductType], null: false, description: 'Dostupné varianty'
      field :in_stock_variants, [Types::ProductType], null: false, description: 'Varianty skladem'
      field :has_variants, GraphQL::Types::Boolean, null: false, description: 'Má produkt varianty?'
      field :variants_count, GraphQL::Types::Int, null: false, description: 'Počet variant'
      field :variant_sku, GraphQL::Types::String, null: true, description: 'SKU varianty'
      field :variant_display_name, GraphQL::Types::String, null: false, description: 'Zobrazovaný název varianty'
      field :variant_attribute_values, [Types::VariantAttributeValueType], null: false,
                                                                           description: 'Hodnoty atributů varianty'

      # VARIANT ATTRIBUTES - Atributy variant
      field :flavor, Types::VariantAttributeValueType, null: true, description: 'Příchuť varianty'
      field :size, Types::VariantAttributeValueType, null: true, description: 'Velikost varianty'
      field :color, Types::VariantAttributeValueType, null: true, description: 'Barva varianty'
    end

    # VARIANT METHODS - GraphQL resolver methods keep original names for API compatibility
    def is_variant_parent # rubocop:disable Naming/PredicatePrefix
      object.variant_parent?
    end

    def is_variant_child # rubocop:disable Naming/PredicatePrefix
      object.variant_child?
    end

    def is_standalone_product # rubocop:disable Naming/PredicatePrefix
      object.standalone_product?
    end

    def has_variants # rubocop:disable Naming/PredicatePrefix
      object.variants?
    end
  end
end
