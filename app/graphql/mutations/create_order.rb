# frozen_string_literal: true

module Mutations
  class CreateOrder < BaseMutation
    include Mutations::Concerns::OrderProcessing

    description 'Vytvořit novou objednávku'

    # Input type pro položky objednávky
    class OrderItemInput < Types::BaseInputObject
      argument :product_id, ID, required: true, description: 'ID produktu'
      argument :quantity, Integer, required: true, description: 'Množství'
    end

    # Arguments
    argument :items, [OrderItemInput], required: true, description: 'Seznam položek objednávky'
    argument :currency, String, required: false, description: 'Měna objednávky (default: CZK)'

    # Return fields
    field :order, Types::OrderType, null: true, description: 'Vytvořená objednávka'
    field :errors, [String], null: false, description: 'Seznam chyb'

    def resolve(items:, currency: 'CZK')
      # Kontrola autentizace
      current_user = context[:current_user]
      return authentication_error unless current_user

      # Validace vstupních dat
      validation_result = validate_input(items, currency)
      return validation_result if validation_result

      # Vytvoření objednávky v transakci
      create_order_with_items(current_user, items, currency)
    end

    private

    def authentication_error
      {
        order: nil,
        errors: ['Musíte být přihlášeni pro vytvoření objednávky']
      }
    end

    def validate_input(items, currency)
      if items.empty?
        return {
          order: nil,
          errors: ['Objednávka musí obsahovat alespoň jednu položku']
        }
      end

      return unless %w[CZK EUR].exclude?(currency)

      {
        order: nil,
        errors: ['Nepodporovaná měna. Podporovány jsou: CZK, EUR']
      }
    end

    def create_order_with_items(current_user, items, currency)
      ActiveRecord::Base.transaction do
        products = load_and_validate_products(items)
        validate_stock_availability(items, products)

        total_cents, order_items_data = calculate_order_totals(items, products)

        order = create_order(current_user, total_cents, currency)
        create_order_items(order, order_items_data)

        # INVENTORY: Reserve stock for each item
        reserve_stock_for_order(order_items_data)

        { order: order, errors: [] }
      rescue ActiveRecord::RecordInvalid => e
        { order: nil, errors: e.record.errors.full_messages }
      rescue InsufficientStockError, ActiveRecord::Rollback => e
        { order: nil, errors: [e.message] }
      end
    end
  end
end
