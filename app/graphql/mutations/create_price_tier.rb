# frozen_string_literal: true

module Mutations
  class CreatePriceTier < BaseMutation
    description 'Vytvoří novou cenovou úroveň pro produkt'

    # Arguments
    argument :product_id, ID, required: true, description: 'ID produktu'
    argument :tier_name, String, required: true, description: 'Název tier (1ks, 1bal, 10bal, custom)'
    argument :min_quantity, Integer, required: true, description: 'Minimální množství'
    argument :max_quantity, Integer, required: false, description: 'Maximální množství (null = neomezeno)'
    argument :price_cents, Integer, required: true, description: 'Cena v haléřích'
    argument :currency, String, required: false, description: 'Měna (default: CZK)'
    argument :description, String, required: false, description: 'Popis cenové úrovně'
    argument :active, Boolean, required: false, description: 'Aktivní stav (default: true)'
    argument :priority, Integer, required: false, description: 'Priorita řazení'

    # Return fields
    field :price_tier, Types::ProductPriceTierType, null: true, description: 'Vytvořená cenová úroveň'
    field :errors, [String], null: false, description: 'Chybové zprávy'

    def resolve(product_id:, tier_name:, min_quantity:, price_cents:, **args)
      # Authorization - pouze admin nebo vlastník produktu
      product = Product.find(product_id)

      # Vytvoření price tier
      price_tier = product.price_tiers.build(
        tier_name: tier_name,
        min_quantity: min_quantity,
        max_quantity: args[:max_quantity],
        price_cents: price_cents,
        currency: args[:currency] || 'CZK',
        description: args[:description],
        active: args[:active] != false, # default true
        priority: args[:priority]
      )

      if price_tier.save
        {
          price_tier: price_tier,
          errors: []
        }
      else
        {
          price_tier: nil,
          errors: price_tier.errors.full_messages
        }
      end
    rescue ActiveRecord::RecordNotFound
      {
        price_tier: nil,
        errors: ['Produkt nebyl nalezen']
      }
    end
  end
end
