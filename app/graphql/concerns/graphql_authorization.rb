# frozen_string_literal: true

module GraphqlAuthorization
  extend ActiveSupport::Concern

  class_methods do
    # Relay-style Object Identification with security
    def id_from_object(object, _type_definition, query_ctx)
      # Ensure we have permission to access this object
      if object.respond_to?(:user_id) && query_ctx[:current_user]
        user = query_ctx[:current_user]
        unless object.user_id == user.id || user.admin?
          Rails.logger.warn("Unauthorized access attempt to object #{object.class}##{object.id}")
          return nil
        end
      end

      object.to_gid_param
    end

    def object_from_id(global_id, query_ctx)
      object = GlobalID.find(global_id)
      return nil unless object

      # Security check: verify user has access to this object
      if object.respond_to?(:user_id) && query_ctx[:current_user]
        user = query_ctx[:current_user]
        unless object.user_id == user.id || user.admin?
          Rails.logger.warn("Unauthorized access attempt via GlobalID: #{global_id}")
          return nil
        end
      end

      object
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn("Object not found for GlobalID: #{global_id}")
      nil
    end
  end
end
