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

    # INVENTORY MANAGEMENT - Skladové hospodářství
    field :quantity, Integer, null: false, description: 'Počet kusů na skladě'
    field :low_stock_threshold, Integer, null: false, description: 'Minimální počet kusů na skladě'

    # INVENTORY STATUS - Stavové informace
    field :in_stock, Boolean, null: false, description: 'Je produkt skladem?'
    field :out_of_stock, Boolean, null: false, description: 'Je produkt vyprodaný?'
    field :low_stock, Boolean, null: false, description: 'Je produkt na minimu?'
    field :stock_status, String, null: false, description: 'Stav zásob (in_stock/low_stock/out_of_stock)'

    # PRODUCT SPECIFICATIONS - Specifikace produktu
    field :weight_value, Float, null: true, description: 'Hmotnost/objem hodnota'
    field :weight_unit, String, null: true, description: 'Jednotka hmotnosti/objemu (kg/g/l/ml)'
    field :formatted_weight, String, null: true, description: 'Formátovaná hmotnost (např. "2.5 kg")'
    field :ingredients, String, null: true, description: 'Složení produktu'
    field :has_weight_info, Boolean, null: false, description: 'Má produkt informace o hmotnosti?'
    field :has_ingredients, Boolean, null: false, description: 'Má produkt uvedené složení?'
    field :is_liquid, Boolean, null: false, description: 'Je produkt tekutý?'
    field :is_solid, Boolean, null: false, description: 'Je produkt pevný?'

    # Helper field pro frontend - cena jako decimal
    field :price_decimal, Float, null: false, description: 'Cena jako desetinné číslo'

    # INVENTORY METHODS - Business logika inventory
    def price_decimal
      object.price
    end

    def stock_status
      return 'out_of_stock' if object.out_of_stock?
      return 'low_stock' if object.low_stock?

      'in_stock'
    end

    # Image fields pro Next.js
    field :image_urls, [String], null: false, description: 'URL obrázků produktu'
    field :has_images, Boolean, null: false, description: 'Má produkt obrázky?'

    def image_urls
      object.images.attached? ? object.images.map { |image| rails_blob_url(image) } : []
    end

    def has_images # rubocop:disable Naming/PredicatePrefix
      images?
    end

    private

    def images?
      object.images.attached?
    end

    # Metadata
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum vytvoření'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum poslední aktualizace'
  end
end
