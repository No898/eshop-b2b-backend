# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    description 'Uživatel systému'

    field :id, ID, null: false, description: 'Unikátní ID uživatele'
    field :email, String, null: false, description: 'Email uživatele'
    field :role, String, null: false, description: 'Role uživatele (customer/admin)'
    field :company_name, String, null: true, description: 'Název firmy (pro B2B zákazníky)'
    field :vat_id, String, null: true, description: 'DIČ (pro B2B zákazníky)'

    # Associations
    field :orders, [Types::OrderType], null: false, description: 'Seznam objednávek uživatele'
    def orders
      current_user = context[:current_user]

      # SECURITY: Only show orders if user has permission
      return [] unless current_user
      return [] unless current_user.can_access_user_data?(object)

      object.orders.order(created_at: :desc)
    end

    # Metadata
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum registrace'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'Datum poslední aktualizace'
  end
end
