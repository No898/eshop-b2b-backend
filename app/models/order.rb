class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy

  validates :total_cents, presence: true, numericality: { greater_than: 0}
  validates :currency, presence: true, inclusion: { in: %w[CZK EUR] }

  enum :status, {
    pending: 0,
    paid: 1,
    shipped: 2,
    delivered: 3,
    cancelled: 4
  }

  scope :recent, -> { order(created_at: :desc) }

  def total_decimal
    total_cents / 100.0
  end
end
