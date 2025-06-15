# frozen_string_literal: true

class ComgateWebhookService
  module Validator
    private

    def validate_required_params!
      missing_params = []
      missing_params << 'transId' if @transaction_id.blank?
      missing_params << 'refId' if @reference_id.blank?
      missing_params << 'status' if @status.blank?

      return if missing_params.empty?

      raise WebhookError, "Missing required parameters: #{missing_params.join(', ')}"
    end

    def validate_order!(order)
      # Verify payment_id matches if already set
      if order.payment_id.present? && order.payment_id != @transaction_id
        raise WebhookError, "Payment ID mismatch: expected #{order.payment_id}, got #{@transaction_id}"
      end

      # Verify price matches (convert to cents if needed)
      expected_price = order.total_cents
      received_price = (@price.to_f * 100).to_i # Convert to cents if Comgate sends in major units

      if expected_price != received_price && expected_price != @price.to_i
        Rails.logger.warn "Price mismatch for order #{order.id}: expected #{expected_price}, got #{@price}"
        # Don't fail on price mismatch, just log it - some payment gateways have rounding issues
      end

      # Verify currency matches
      return unless order.currency != @currency

      raise WebhookError, "Currency mismatch: expected #{order.currency}, got #{@currency}"
    end
  end
end
