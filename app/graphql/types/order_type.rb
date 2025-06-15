# frozen_string_literal: true

module Types
  class OrderType < Types::BaseObject
    description "Objednávka"

    field :id, ID, null: false, description: "Unikátní ID objednávky"
    field :total_cents, Integer, null: false, description: "Celková cena v centech"
    field :currency, String, null: false, description: "Měna (CZK/EUR)"
    field :status, String, null: false, description: "Stav objednávky (pending/paid/shipped/delivered/cancelled)"
    
    # Associations
    field :user, Types::UserType, null: false, description: "Zákazník"
    field :order_items, [Types::OrderItemType], null: false, description: "Položky objednávky"

    # Helper fields pro frontend
    field :total_decimal, Float, null: false, description: "Celková cena jako desetinné číslo"
    def total_decimal
      object.total_decimal
    end

    # Computed fields
    field :items_count, Integer, null: false, description: "Počet položek v objednávce"
    def items_count
      object.order_items.sum(:quantity)
    end

    field :is_pending, Boolean, null: false, description: "Je objednávka čeká na platbu?"
    def is_pending
      object.pending?
    end

    field :is_paid, Boolean, null: false, description: "Je objednávka zaplacená?"
    def is_paid
      object.paid?
    end

    # Metadata
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "Datum vytvoření"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "Datum poslední aktualizace"
  end
end 