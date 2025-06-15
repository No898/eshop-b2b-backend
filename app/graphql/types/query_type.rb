# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # Products queries
    field :products, [Types::ProductType], null: false, description: "Seznam všech dostupných produktů"
    def products
      Product.available.order(:name)
    end

    field :product, Types::ProductType, null: true, description: "Najít produkt podle ID" do
      argument :id, ID, required: true, description: "ID produktu"
    end
    def product(id:)
      Product.available.find_by(id: id)
    end

    # Current user query (pokud je přihlášen)
    field :current_user, Types::UserType, null: true, description: "Aktuálně přihlášený uživatel"
    def current_user
      context[:current_user]
    end

    # User's orders (jen pokud je přihlášen)
    field :my_orders, [Types::OrderType], null: false, description: "Moje objednávky"
    def my_orders
      return [] unless context[:current_user]
      context[:current_user].orders.order(created_at: :desc)
    end
  end
end
