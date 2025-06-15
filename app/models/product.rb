# frozen_string_literal: true

class Product < ApplicationRecord
  has_many :order_items, dependent: :restrict_with_error

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[CZK EUR] }

  scope :available, -> { where(available: true) }

  def price
    price_cents / 100.0
  end
end
