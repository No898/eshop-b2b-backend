# frozen_string_literal: true

module Types
  class VariantAttributeType < Types::BaseObject
    description 'Atribut varianty produktu (příchuť, velikost, barva)'

    field :id, ID, null: false, description: 'Unikátní identifikátor atributu'
    field :name, String, null: false, description: 'Systémový název atributu (flavor, size, color)'
    field :display_name, String, null: false, description: 'Zobrazovaný název atributu (Příchuť, Velikost, Barva)'
    field :description, String, null: true, description: 'Popis atributu'
    field :sort_order, Integer, null: false, description: 'Pořadí řazení'
    field :active, Boolean, null: false, description: 'Zda je atribut aktivní'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum vytvoření'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum poslední aktualizace'

    # Associations
    field :values, [Types::VariantAttributeValueType], null: false, description: 'Hodnoty tohoto atributu'
    field :active_values, [Types::VariantAttributeValueType], null: false,
                                                              description: 'Aktivní hodnoty tohoto atributu'
    field :values_count, Integer, null: false, description: 'Počet aktivních hodnot'

    # Helper fields
    field :is_flavor, Boolean, null: false, description: 'Zda se jedná o příchuť', method: :attribute_flavor?
    field :is_size, Boolean, null: false, description: 'Zda se jedná o velikost', method: :attribute_size?
    field :is_color, Boolean, null: false, description: 'Zda se jedná o barvu', method: :attribute_color?

    def values
      object.variant_attribute_values.ordered
    end

    delegate :active_values, to: :object
  end
end
