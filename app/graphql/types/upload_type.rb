# frozen_string_literal: true

module Types
  class UploadType < Types::BaseScalar
    description 'File upload scalar type'

    def self.coerce_input(value, _context)
      case value
      when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
        # Validýní soubor
        raise GraphQL::CoercionError, 'Neplatný soubor' unless valid_file?(value)

        value
      else
        raise GraphQL::CoercionError, "#{value.inspect} není validní upload"
      end
    end

    def self.coerce_result(value, _context)
      # Pro output vrátíme URL souboru
      case value
      when ActiveStorage::Blob
        Rails.application.routes.url_helpers.rails_blob_url(value)
      when ActiveStorage::Attached::One, ActiveStorage::Attached::Many
        Rails.application.routes.url_helpers.rails_blob_url(value.blob) if value.attached?
      else
        value.to_s
      end
    end

    def self.valid_file?(file)
      return false unless file.respond_to?(:content_type)
      return false unless file.respond_to?(:size)

      # Povolené typy souborů
      allowed_types = %w[
        image/jpeg image/jpg image/png image/gif image/webp
        application/pdf
      ]

      # Max velikost 10MB
      max_size = 10.megabytes

      allowed_types.include?(file.content_type) && file.size <= max_size
    end
  end
end
