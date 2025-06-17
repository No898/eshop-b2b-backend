# frozen_string_literal: true

module Types
  class ProductPriceTierType < Types::BaseObject
    field :id, ID, null: false
    field :tier_name, String, null: false, description: 'Název cenové úrovně (1ks, 1bal, 10bal)'
    field :min_quantity, Integer, null: false, description: 'Minimální množství pro tuto cenu'
    field :max_quantity, Integer, null: true, description: 'Maximální množství (null = neomezeno)'
    field :price_cents, Integer, null: false, description: 'Cena v haléřích'
    field :price_decimal, Float, null: false, description: 'Cena v korunách (pro frontend)'
    field :currency, String, null: false, description: 'Měna (CZK, EUR)'
    field :description, String, null: true, description: 'Popis cenové úrovně'
    field :active, Boolean, null: false, description: 'Zda je cenová úroveň aktivní'
    field :priority, Integer, null: false, description: 'Priorita řazení'
    field :quantity_range_description, String, null: false, description: 'Popis rozsahu množství'
    field :savings_percentage, Float, null: false, description: 'Procento úspory oproti základní ceně'
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Helper field pro frontend
    def price_decimal
      object.price
    end

    delegate :quantity_range_description, to: :object

    def savings_percentage
      object.savings_compared_to_base_price
    end
  end
end
