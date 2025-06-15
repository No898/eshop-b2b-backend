# frozen_string_literal: true

module Types
  class ProductType < Types::BaseObject
    description 'Produkt v e-shopu'

    field :id, ID, null: false, description: 'Unikátní ID produktu'
    field :name, String, null: false, description: 'Název produktu'
    field :description, String, null: true, description: 'Popis produktu'
    field :price_cents, Integer, null: false, description: 'Cena v centech'
    field :currency, String, null: false, description: 'Měna (CZK/EUR)'
    field :available, Boolean, null: false, description: 'Dostupnost produktu'

    # Helper field pro frontend - cena jako decimal
    field :price_decimal, Float, null: false, description: 'Cena jako desetinné číslo'
    delegate :price_decimal, to: :object

    # Metadata
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum vytvoření'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum poslední aktualizace'
  end
end
