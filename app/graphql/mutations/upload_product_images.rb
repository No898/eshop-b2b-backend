# frozen_string_literal: true

module Mutations
  class UploadProductImages < Mutations::BaseMutation
    description 'Nahrání obrázků k produktu'

    # Arguments
    argument :product_id, ID, required: true, description: 'ID produktu'
    argument :images, [Types::UploadType], required: true, description: 'Seznam obrázků k nahrání'

    # Return fields
    field :product, Types::ProductType, null: true, description: 'Aktualizovaný produkt'
    field :success, Boolean, null: false, description: 'Úspěch operace'
    field :errors, [String], null: false, description: 'Seznam chyb'

    def resolve(product_id:, images:)
      Rails.logger.info "🖼️ Uploading #{images.size} images for product #{product_id}"

      # Check authorization and validation
      error_response = check_permissions_and_validation(product_id, images)
      return error_response if error_response

      # Upload images
      upload_images_to_product(@product, images)
    end

    private

    def check_permissions_and_validation(product_id, images)
      return error_response(['Nemáte oprávnění k nahrávání obrázků']) unless context[:current_user]&.admin?

      @product = Product.find_by(id: product_id)
      return error_response(['Produkt nebyl nalezen']) unless @product

      validation_errors = validate_images(images)
      return error_response(validation_errors) if validation_errors.any?

      nil
    end

    def upload_images_to_product(product, images)
      ActiveRecord::Base.transaction do
        images.each_with_index do |image, index|
          Rails.logger.info "Uploading image #{index + 1}/#{images.size}: #{image.original_filename}"
          product.images.attach(image)
        end
      end

      Rails.logger.info "✅ Successfully uploaded #{images.size} images for product #{product.id}"
      success_response(product)
    rescue StandardError => e
      Rails.logger.error "❌ Failed to upload images: #{e.message}"
      error_response(["Nahrávání obrázků se nezdařilo: #{e.message}"])
    end

    def success_response(product)
      { product: product.reload, success: true, errors: [] }
    end

    def error_response(errors)
      { product: nil, success: false, errors: errors }
    end

    def validate_images(images)
      errors = []

      # Check image count
      errors << 'Maximálně 10 obrázků na produkt' if images.size > 10

      errors << 'Musíte vybrat alespoň jeden obrázek' if images.empty?

      # Validate each image
      images.each_with_index do |image, index|
        image_errors = validate_single_image(image, index + 1)
        errors.concat(image_errors)
      end

      errors
    end

    def validate_single_image(image, position)
      errors = []

      unless image.respond_to?(:content_type)
        errors << "Obrázek #{position}: Neplatný formát souboru"
        return errors
      end

      # Check file type
      allowed_types = %w[image/jpeg image/jpg image/png image/gif image/webp]
      unless allowed_types.include?(image.content_type.downcase)
        errors << "Obrázek #{position}: Povolené formáty: JPEG, PNG, GIF, WebP"
      end

      # Check file size
      max_size = 5.megabytes
      errors << "Obrázek #{position}: Maximální velikost #{max_size / 1.megabyte} MB" if image.size > max_size

      # Check filename
      errors << "Obrázek #{position}: Chybí název souboru" if image.original_filename.blank?

      errors
    end
  end
end
