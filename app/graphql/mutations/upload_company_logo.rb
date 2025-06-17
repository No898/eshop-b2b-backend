# frozen_string_literal: true

module Mutations
  class UploadCompanyLogo < Mutations::BaseMutation
    description 'Nahrání loga firmy'

    # Arguments
    argument :logo, Types::UploadType, required: true, description: 'Logo firmy'

    # Return fields
    field :user, Types::UserType, null: true, description: 'Aktualizovaný uživatel'
    field :success, Boolean, null: false, description: 'Úspěch operace'
    field :errors, [String], null: false, description: 'Seznam chyb'

    def resolve(logo:)
      current_user = context[:current_user]
      return error_response(['Musíte být přihlášeni']) unless current_user
      if current_user.company_name.blank?
        return error_response(['Logo firmy lze nahrát jen pro B2B zákazníky s vyplněným názvem firmy'])
      end

      Rails.logger.info "🏢 Uploading company logo for user #{current_user.id} (#{current_user.company_name})"

      validation_errors = validate_logo(logo)
      return error_response(validation_errors) if validation_errors.any?

      upload_logo_for_user(current_user, logo)
    end

    private

    def upload_logo_for_user(user, logo)
      user.company_logo.purge if user.company_logo.attached?
      user.company_logo.attach(logo)

      Rails.logger.info "✅ Successfully uploaded company logo for user #{user.id}"
      success_response(user)
    rescue StandardError => e
      Rails.logger.error "❌ Failed to upload company logo: #{e.message}"
      error_response(["Nahrávání loga se nezdařilo: #{e.message}"])
    end

    def success_response(user)
      { user: user.reload, success: true, errors: [] }
    end

    def error_response(errors)
      { user: nil, success: false, errors: errors }
    end

    def validate_logo(logo)
      errors = []

      unless logo.respond_to?(:content_type)
        errors << 'Neplatný formát souboru'
        return errors
      end

      # Logo může být obrázek nebo vektorový formát
      allowed_types = %w[
        image/jpeg image/jpg image/png image/gif image/webp
        image/svg+xml
        application/pdf
      ]
      unless allowed_types.include?(logo.content_type.downcase)
        errors << 'Povolené formáty loga: JPEG, PNG, GIF, WebP, SVG, PDF'
      end

      # Check file size - větší limit pro logo (může být vyšší rozlišení)
      max_size = 3.megabytes
      errors << "Maximální velikost loga: #{max_size / 1.megabyte} MB" if logo.size > max_size

      # Check filename
      errors << 'Chybí název souboru' if logo.original_filename.blank?

      errors
    end
  end
end
