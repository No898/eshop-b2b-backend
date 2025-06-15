# frozen_string_literal: true

module Types
  class OrderItemType < Types::BaseObject
    description 'Položka objednávky'

    field :id, ID, null: false, description: 'Unikátní ID položky'
    field :quantity, Integer, null: false, description: 'Množství produktu'
    field :unit_price_cents, Integer, null: false, description: 'Jednotková cena v centech (historická)'

    # Associations
    field :product, Types::ProductType, null: false, description: 'Produkt v objednávce'
    field :order, Types::OrderType, null: false, description: 'Objednávka'

    # Helper fields pro frontend
    field :unit_price_decimal, Float, null: false, description: 'Jednotková cena jako desetinné číslo'
    delegate :unit_price_decimal, to: :object

    field :total_cents, Integer, null: false, description: 'Celková cena za položku v centech'
    delegate :total_cents, to: :object

    field :total_decimal, Float, null: false, description: 'Celková cena za položku jako desetinné číslo'
    delegate :total_decimal, to: :object

    # Metadata
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum vytvoření'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum poslední aktualizace'
  end
end
