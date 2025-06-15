# frozen_string_literal: true

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price_cents, presence: true, numericality: { greater_than: 0 }

  def unit_price_decimal
    unit_price_cents / 100.0
  end

  def total_cents
    quantity * unit_price_cents
  end

  def total_decimal
    total_cents / 100.0
  end
end
