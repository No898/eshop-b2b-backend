# frozen_string_literal: true

module Types
  class VariantAttributeValueType < Types::BaseObject
    description 'Hodnota atributu varianty (jahoda, velká, červená)'

    field :id, ID, null: false, description: 'Unikátní identifikátor hodnoty'
    field :value, String, null: false, description: 'Systémová hodnota (strawberry, large, red)'
    field :display_value, String, null: false, description: 'Zobrazovaná hodnota (Jahoda, Velká, Červená)'
    field :color_code, String, null: true, description: 'Hex kód barvy pro vizuální reprezentaci (#FF0000)'
    field :description, String, null: true, description: 'Popis hodnoty'
    field :sort_order, Integer, null: false, description: 'Pořadí řazení'
    field :active, Boolean, null: false, description: 'Zda je hodnota aktivní'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum vytvoření'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum poslední aktualizace'

    # Associations
    field :variant_attribute, Types::VariantAttributeType, null: false, description: 'Atribut ke kterému hodnota patří'
    field :products_count, Integer, null: false, description: 'Počet produktů používajících tuto hodnotu'

    # Helper fields
    field :attribute_name, String, null: false, description: 'Název atributu (flavor, size, color)'
    field :attribute_display_name, String, null: false, description: 'Zobrazovaný název atributu'
    field :has_color, Boolean, null: false, description: 'Zda má hodnota přiřazenou barvu', method: :has_color?
    field :is_flavor, Boolean, null: false, description: 'Zda se jedná o příchuť', method: :flavor?
    field :is_size, Boolean, null: false, description: 'Zda se jedná o velikost', method: :size?
    field :is_color, Boolean, null: false, description: 'Zda se jedná o barvu', method: :color?
    field :display_with_attribute, String, null: false, description: 'Zobrazení s názvem atributu (Příchuť: Jahoda)'

    def attribute_name
      object.variant_attribute.name
    end

    def attribute_display_name
      object.variant_attribute.display_name
    end
  end
end
