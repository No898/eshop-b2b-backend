# frozen_string_literal: true

require_relative 'comgate_webhook_service/validator'
require_relative 'comgate_webhook_service/status_processor'

class ComgateWebhookService
  include Validator
  include StatusProcessor

  class WebhookError < StandardError; end
  class OrderNotFoundError < WebhookError; end
  class InvalidStatusError < WebhookError; end

  # Comgate payment status mapping
  COMGATE_STATUS_MAPPING = {
    'PAID' => :payment_completed,
    'CANCELLED' => :payment_cancelled,
    'TIMEOUT' => :payment_failed,
    'PENDING' => :payment_pending
  }.freeze

  def initialize(webhook_params)
    @params = webhook_params.to_h.with_indifferent_access
    @transaction_id = @params[:transId]
    @reference_id = @params[:refId]
    @status = @params[:status]
    @price = @params[:price]
    @currency = @params[:curr]
    @test_mode = @params[:test] == 'true'
  end

  def process
    validate_required_params!

    order = find_order
    validate_order!(order)

    process_status_change(order)
  rescue WebhookError => e
    Rails.logger.error "Webhook processing error: #{e.message}"
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error "Unexpected webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: 'Internal processing error' }
  end

  private

  def find_order
    # First try to find by payment_id (transId)
    order = Order.find_by(payment_id: @transaction_id) if @transaction_id.present?

    # Fallback to reference_id (order ID)
    order ||= Order.find_by(id: @reference_id) if @reference_id.present?

    raise OrderNotFoundError, "Order not found for transId: #{@transaction_id}, refId: #{@reference_id}" unless order

    order
  end
end
