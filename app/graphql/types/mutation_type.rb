# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # Authentication mutations
    field :login_user, mutation: Mutations::LoginUser
    field :register_user, mutation: Mutations::RegisterUser

    # Order mutations
    field :create_order, mutation: Mutations::CreateOrder
    field :pay_order, mutation: Mutations::PayOrder

    # Upload mutations
    field :upload_product_images, mutation: Mutations::UploadProductImages
    field :upload_user_avatar, mutation: Mutations::UploadUserAvatar
    field :upload_company_logo, mutation: Mutations::UploadCompanyLogo

    # Bulk pricing mutations
    field :create_price_tier, mutation: Mutations::CreatePriceTier

    # Product variant mutations
    field :create_product_variant, mutation: Mutations::CreateProductVariant
  end
end
