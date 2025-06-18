# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    description 'Uživatel systému'

    field :id, ID, null: false, description: 'Unikátní ID uživatele'
    field :email, String, null: false, description: 'Email uživatele'
    field :role, String, null: false, description: 'Role uživatele (customer/admin)'
    field :company_name, String, null: true, description: 'Název firmy (pro B2B zákazníky)'
    field :vat_id, String, null: true, description: 'DIČ (pro B2B zákazníky)'

    # Avatar and company logo URLs pro Next.js
    field :avatar_url, String, null: true, description: 'URL avataru uživatele'
    field :company_logo_url, String, null: true, description: 'URL loga firmy'

    def avatar_url
      object.avatar.attached? ? rails_blob_url(object.avatar) : nil
    end

    def company_logo_url
      object.company_logo.attached? ? rails_blob_url(object.company_logo) : nil
    end

    # Associations - use lazy loading to avoid circular dependency
    field :orders, [-> { Types::OrderType }], null: false, description: 'Seznam objednávek uživatele'
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
