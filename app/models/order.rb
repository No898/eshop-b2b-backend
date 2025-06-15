# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy

  validates :total_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[CZK EUR] }

  enum :status, {
    pending: 0,
    paid: 1,
    shipped: 2,
    delivered: 3,
    cancelled: 4
  }

  enum :payment_status, {
    no_payment: 0,
    payment_pending: 1,
    payment_completed: 2,
    payment_failed: 3,
    payment_cancelled: 4
  }
  scope :recent, -> { order(created_at: :desc) }

  def total_decimal
    total_cents / 100.0
  end
end
