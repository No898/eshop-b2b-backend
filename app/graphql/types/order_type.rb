# frozen_string_literal: true

module Types
  class OrderType < Types::BaseObject
    description 'Objednávka'

    field :id, ID, null: false, description: 'Unikátní ID objednávky'
    field :total_cents, Integer, null: false, description: 'Celková cena v centech'
    field :currency, String, null: false, description: 'Měna (CZK/EUR)'
    field :status, String, null: false, description: 'Stav objednávky (pending/paid/shipped/delivered/cancelled)'

    # Associations
    field :user, Types::UserType, null: false, description: 'Zákazník'
    field :order_items, [Types::OrderItemType], null: false, description: 'Položky objednávky'

    # Helper fields pro frontend
    field :total_decimal, Float, null: false, description: 'Celková cena jako desetinné číslo'
    delegate :total_decimal, to: :object

    # Computed fields
    field :items_count, Integer, null: false, description: 'Počet položek v objednávce'
    def items_count
      object.order_items.sum(:quantity)
    end

    field :is_pending, Boolean, null: false, description: 'Je objednávka čeká na platbu?'
    delegate :pending?, to: :object

    field :is_paid, Boolean, null: false, description: 'Je objednávka zaplacená?'
    delegate :paid?, to: :object

    # Metadata
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum vytvoření'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum poslední aktualizace'

    # Platební pole
    field :payment_status, String, null: false, description: 'Stav platby'
    field :payment_id, String, null: true, description: 'ID platby v Comgate'
    field :payment_url, String, null: true, description: 'URL pro platbu'

    # Helper metody pro platební stavy
    field :payment_pending, Boolean, null: false, description: 'Čeká na platbu'
    field :payment_completed, Boolean, null: false, description: 'Platba dokončena'
    field :payment_failed, Boolean, null: false, description: 'Platba selhala'

    def payment_pending
      object.payment_pending?
    end

    def payment_completed
      object.payment_completed?
    end

    def payment_failed
      object.payment_failed?
    end
  end
end
