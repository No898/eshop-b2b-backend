# frozen_string_literal: true

module Mutations
  class CreateOrder < BaseMutation
    description "Vytvořit novou objednávku"

    # Input type pro položky objednávky
    class OrderItemInput < Types::BaseInputObject
      argument :product_id, ID, required: true, description: "ID produktu"
      argument :quantity, Integer, required: true, description: "Množství"
    end

    # Arguments
    argument :items, [OrderItemInput], required: true, description: "Seznam položek objednávky"
    argument :currency, String, required: false, description: "Měna objednávky (default: CZK)"

    # Return fields
    field :order, Types::OrderType, null: true, description: "Vytvořená objednávka"
    field :errors, [String], null: false, description: "Seznam chyb"

    def resolve(items:, currency: "CZK")
      # Kontrola autentizace
      current_user = context[:current_user]
      unless current_user
        return {
          order: nil,
          errors: ["Musíte být přihlášeni pro vytvoření objednávky"]
        }
      end

      # Validace vstupních dat
      if items.empty?
        return {
          order: nil,
          errors: ["Objednávka musí obsahovat alespoň jednu položku"]
        }
      end

      # Kontrola validity měny
      unless %w[CZK EUR].include?(currency)
        return {
          order: nil,
          errors: ["Nepodporovaná měna. Podporovány jsou: CZK, EUR"]
        }
      end

      ActiveRecord::Base.transaction do
        begin
          # Načteme produkty a zkontrolujeme dostupnost
          product_ids = items.map { |item| item[:product_id] }
          products = Product.available.where(id: product_ids).index_by(&:id)

          # Kontrola existence všech produktů
          missing_products = product_ids - products.keys.map(&:to_s)
          if missing_products.any?
            raise ActiveRecord::Rollback, "Produkty s ID #{missing_products.join(', ')} nejsou dostupné"
          end

          # Výpočet celkové ceny
          total_cents = 0
          order_items_data = []

          items.each do |item|
            product = products[item[:product_id].to_i]
            quantity = item[:quantity]

            if quantity <= 0
              raise ActiveRecord::Rollback, "Množství musí být větší než 0"
            end

            item_total = product.price_cents * quantity
            total_cents += item_total

            order_items_data << {
              product: product,
              quantity: quantity,
              unit_price_cents: product.price_cents
            }
          end

          # Vytvoření objednávky
          order = Order.create!(
            user: current_user,
            total_cents: total_cents,
            currency: currency,
            status: :pending
          )

          # Vytvoření položek objednávky
          order_items_data.each do |item_data|
            order.order_items.create!(
              product: item_data[:product],
              quantity: item_data[:quantity],
              unit_price_cents: item_data[:unit_price_cents]
            )
          end

          {
            order: order,
            errors: []
          }
        rescue ActiveRecord::RecordInvalid => e
          {
            order: nil,
            errors: e.record.errors.full_messages
          }
        rescue ActiveRecord::Rollback => e
          {
            order: nil,
            errors: [e.message]
          }
        end
      end
    end
  end
end 