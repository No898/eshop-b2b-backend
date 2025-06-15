# frozen_string_literal: true

module Mutations
  class CreateOrder < BaseMutation
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
        total_cents, order_items_data = calculate_order_totals(items, products)

        order = create_order(current_user, total_cents, currency)
        create_order_items(order, order_items_data)

        { order: order, errors: [] }
      rescue ActiveRecord::RecordInvalid => e
        { order: nil, errors: e.record.errors.full_messages }
      rescue ActiveRecord::Rollback => e
        { order: nil, errors: [e.message] }
      end
    end

    def load_and_validate_products(items)
      product_ids = items.pluck(:product_id)
      products = Product.available.where(id: product_ids).index_by(&:id)

      missing_products = product_ids - products.keys.map(&:to_s)
      if missing_products.any?
        raise ActiveRecord::Rollback, "Produkty s ID #{missing_products.join(', ')} nejsou dostupné"
      end

      products
    end

    def calculate_order_totals(items, products)
      total_cents = 0
      order_items_data = []

      items.each do |item|
        product = products[item[:product_id].to_i]
        quantity = item[:quantity]

        raise ActiveRecord::Rollback, 'Množství musí být větší než 0' if quantity <= 0

        item_total = product.price_cents * quantity
        total_cents += item_total

        order_items_data << {
          product: product,
          quantity: quantity,
          unit_price_cents: product.price_cents
        }
      end

      [total_cents, order_items_data]
    end

    def create_order(current_user, total_cents, currency)
      Order.create!(
        user: current_user,
        total_cents: total_cents,
        currency: currency,
        status: :pending
      )
    end

    def create_order_items(order, order_items_data)
      order_items_data.each do |item_data|
        order.order_items.create!(
          product: item_data[:product],
          quantity: item_data[:quantity],
          unit_price_cents: item_data[:unit_price_cents]
        )
      end
    end
  end
end
