# frozen_string_literal: true

module Mutations
  class UploadUserAvatar < Mutations::BaseMutation
    description 'Nahrání avataru uživatele'

    # Arguments
    argument :avatar, Types::UploadType, required: true, description: 'Avatar obrázek'

    # Return fields
    field :user, Types::UserType, null: true, description: 'Aktualizovaný uživatel'
    field :success, Boolean, null: false, description: 'Úspěch operace'
    field :errors, [String], null: false, description: 'Seznam chyb'

    def resolve(avatar:)
      current_user = context[:current_user]
      return error_response(['Musíte být přihlášeni']) unless current_user

      Rails.logger.info "👤 Uploading avatar for user #{current_user.id}"

      validation_errors = validate_avatar(avatar)
      return error_response(validation_errors) if validation_errors.any?

      upload_avatar_for_user(current_user, avatar)
    end

    private

    def upload_avatar_for_user(user, avatar)
      user.avatar.purge if user.avatar.attached?
      user.avatar.attach(avatar)

      Rails.logger.info "✅ Successfully uploaded avatar for user #{user.id}"
      success_response(user)
    rescue StandardError => e
      Rails.logger.error "❌ Failed to upload avatar: #{e.message}"
      error_response(["Nahrávání avataru se nezdařilo: #{e.message}"])
    end

    def success_response(user)
      { user: user.reload, success: true, errors: [] }
    end

    def error_response(errors)
      { user: nil, success: false, errors: errors }
    end

    def validate_avatar(avatar)
      errors = []

      unless avatar.respond_to?(:content_type)
        errors << 'Neplatný formát souboru'
        return errors
      end

      # Check file type - jen obrázky pro avatar
      allowed_types = %w[image/jpeg image/jpg image/png image/gif image/webp]
      unless allowed_types.include?(avatar.content_type.downcase)
        errors << 'Povolené formáty avataru: JPEG, PNG, GIF, WebP'
      end

      # Check file size - menší limit pro avatar
      max_size = 2.megabytes
      errors << "Maximální velikost avataru: #{max_size / 1.megabyte} MB" if avatar.size > max_size

      # Check filename
      errors << 'Chybí název souboru' if avatar.original_filename.blank?

      errors
    end
  end
end
