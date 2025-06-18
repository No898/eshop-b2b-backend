# frozen_string_literal: true

module ProductImages
  extend ActiveSupport::Concern

  # IMAGE METHODS
  def images?
    images.attached?
  end

  def primary_image
    images.first
  end
end
