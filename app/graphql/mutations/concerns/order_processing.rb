# frozen_string_literal: true

module Mutations
  module Concerns
    module OrderProcessing
      extend ActiveSupport::Concern

      private

      def load_and_validate_products(items)
        product_ids = items.pluck(:product_id)
        products = Product.available.where(id: product_ids).index_by(&:id)

        missing_products = product_ids - products.keys.map(&:to_s)
        if missing_products.any?
          raise ActiveRecord::Rollback, "Produkty s ID #{missing_products.join(', ')} nejsou dostupné"
        end

        products
      end

      def validate_stock_availability(items, products)
        stock_errors = []

        items.each do |item|
          product = products[item[:product_id].to_i]
          requested_quantity = item[:quantity]

          unless product.can_fulfill_order?(requested_quantity)
            stock_errors << "Produkt '#{product.name}' není dostupný v požadovaném množství " \
                            "(požadováno: #{requested_quantity}, dostupné: #{product.quantity})"
          end
        end

        return unless stock_errors.any?

        raise ActiveRecord::Rollback, stock_errors.join('; ')
      end

      def reserve_stock_for_order(order_items_data)
        order_items_data.each do |item_data|
          product = item_data[:product]
          quantity = item_data[:quantity]

          # THREAD SAFETY: Reserve stock atomically
          product.reserve_stock!(quantity)
        end
      rescue InsufficientStockError => e
        # ROLLBACK: If any stock reservation fails, rollback the entire transaction
        Rails.logger.error("Stock reservation failed during order creation: #{e.message}")
        raise e
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
end
