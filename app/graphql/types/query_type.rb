# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: 'Fetches an object given its ID.' do
      argument :id, ID, required: true, description: 'ID of the object.'
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, { null: true }], null: true,
                                                     description: 'Fetches a list of objects given a list of IDs.' do
      argument :ids, [ID], required: true, description: 'IDs of the objects.'
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # Products queries
    field :products, [Types::ProductType], null: false, description: 'Seznam všech dostupných produktů'
    def products
      Product.available.order(:name)
    end

    field :product, Types::ProductType, null: true, description: 'Najít produkt podle ID' do
      argument :id, ID, required: true, description: 'ID produktu'
    end
    def product(id:)
      Product.available.find_by(id: id)
    end

    # Current user query (pokud je přihlášen)
    field :current_user, Types::UserType, null: true, description: 'Aktuálně přihlášený uživatel'
    def current_user
      context[:current_user]
    end

    # User's orders (jen pokud je přihlášen)
    field :my_orders, [Types::OrderType], null: false, description: 'Moje objednávky'
    def my_orders
      return [] unless context[:current_user]

      context[:current_user].orders.order(created_at: :desc)
    end

    # Variant attributes queries
    field :variant_attributes, [Types::VariantAttributeType], null: false, description: 'Seznam všech atributů variant'
    def variant_attributes
      VariantAttribute.active.ordered.with_values
    end

    field :variant_attribute_values, [Types::VariantAttributeValueType], null: false,
                                                                         description: 'Seznam všech hodnot atributů' do
      argument :attribute_name, String, required: false,
                                        description: 'Filtrovat podle názvu atributu (flavor, size, color)'
    end
    def variant_attribute_values(attribute_name: nil)
      if attribute_name.present?
        VariantAttributeValue.for_attribute(attribute_name).active.ordered
      else
        VariantAttributeValue.active.ordered
      end
    end

    # Specific variant value queries
    field :flavors, [Types::VariantAttributeValueType], null: false, description: 'Seznam všech příchutí'
    delegate :flavors, to: :VariantAttributeValue

    field :sizes, [Types::VariantAttributeValueType], null: false, description: 'Seznam všech velikostí'
    delegate :sizes, to: :VariantAttributeValue

    field :colors, [Types::VariantAttributeValueType], null: false, description: 'Seznam všech barev'
    delegate :colors, to: :VariantAttributeValue
  end
end
