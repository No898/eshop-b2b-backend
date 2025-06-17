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

  # CALLBACKS - Stock management
  before_update :release_stock_on_cancellation, if: :status_changed_to_cancelled?

  def total_decimal
    total_cents / 100.0
  end

  # BUSINESS METHODS - Stock operations
  def release_reserved_stock!
    return unless can_release_stock?

    ActiveRecord::Base.transaction do
      order_items.each do |item|
        item.product.release_stock!(item.quantity)
        Rails.logger.info(
          "Stock released for cancelled order: Order #{id}, " \
          "Product #{item.product.name}, Quantity: #{item.quantity}"
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to release stock for order #{id}: #{e.message}")
    raise e
  end

  def can_release_stock?
    cancelled? && order_items.any?
  end

  # BUSINESS METHODS - Order lifecycle
  def can_be_cancelled?
    pending? || payment_pending?
  end

  def cancel_with_stock_release!
    raise "Order #{id} cannot be cancelled (current status: #{status})" unless can_be_cancelled?

    ActiveRecord::Base.transaction do
      update!(status: :cancelled, payment_status: :payment_cancelled)
      release_reserved_stock!
    end
  end

  private

  def status_changed_to_cancelled?
    status_changed? && cancelled?
  end

  def release_stock_on_cancellation
    return unless status_changed_to_cancelled?

    # Schedule stock release after successful save
    after_commit :release_reserved_stock!
  end
end
