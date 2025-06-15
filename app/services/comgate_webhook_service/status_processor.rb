# frozen_string_literal: true

class ComgateWebhookService
  module StatusProcessor
    private

    def process_status_change(order)
      old_status = order.payment_status
      new_status = map_comgate_status(@status)

      if status_change_allowed?(old_status, new_status)
        update_order_status!(order, new_status)
        log_status_change(order, old_status, new_status)

        create_success_response(order, old_status, new_status)
      else
        create_invalid_transition_response(order, old_status, new_status)
      end
    end

    def map_comgate_status(comgate_status)
      mapped_status = COMGATE_STATUS_MAPPING[comgate_status.upcase]

      raise InvalidStatusError, "Unknown Comgate status: #{comgate_status}" unless mapped_status

      mapped_status
    end

    def status_change_allowed?(old_status, new_status)
      old_status_sym = old_status.to_sym
      new_status_sym = new_status.to_sym

      # Define allowed status transitions
      allowed_transitions = {
        no_payment: %i[payment_pending payment_completed payment_failed payment_cancelled],
        payment_pending: %i[payment_completed payment_failed payment_cancelled],
        payment_completed: [], # Final state - no transitions allowed
        payment_failed: %i[payment_pending payment_completed], # Allow retry
        payment_cancelled: [:payment_pending] # Allow retry
      }

      return true if old_status_sym == new_status_sym # Same status is always allowed

      allowed_transitions[old_status_sym]&.include?(new_status_sym) || false
    end

    def update_order_status!(order, new_status)
      order.transaction do
        # Update payment_id if not set
        order.payment_id = @transaction_id if order.payment_id.blank?

        # Update payment status
        order.payment_status = new_status

        # Update order status based on payment status
        case new_status
        when :payment_completed
          order.status = :paid if order.pending?
        when :payment_failed, :payment_cancelled
          # Keep order as pending so it can be retried
          order.status = :pending if order.paid?
        end

        order.save!
      end
    end

    def create_success_response(order, old_status, new_status)
      {
        success: true,
        message: "Order #{order.id} status updated from #{old_status} to #{new_status}",
        order_id: order.id,
        old_status: old_status,
        new_status: new_status
      }
    end

    def create_invalid_transition_response(order, old_status, new_status)
      Rails.logger.warn "Invalid status transition for order #{order.id}: #{old_status} -> #{new_status}"
      {
        success: false,
        error: "Invalid status transition: #{old_status} -> #{new_status}"
      }
    end

    def log_status_change(order, old_status, new_status)
      Rails.logger.info "Comgate webhook processed for order #{order.id}:"
      Rails.logger.info "  Transaction ID: #{@transaction_id}"
      Rails.logger.info "  Status change: #{old_status} -> #{new_status}"
      Rails.logger.info "  Price: #{@price} #{@currency}"
      Rails.logger.info "  Test mode: #{@test_mode}"
    end
  end
end
