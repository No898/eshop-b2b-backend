# frozen_string_literal: true

module Mutations
  class PayOrder < BaseMutation
    description 'Initiate payment for existing order'

    argument :order_id, ID, required: true, description: 'Order ID to pay for'

    field :success, Boolean, null: false, description: 'Whether payment was successfully created'
    field :payment_url, String, null: true, description: 'URL to redirect for payment'
    field :payment_id, String, null: true, description: 'Payment ID from Comgate'
    field :error_code, String, null: true, description: 'Error code for frontend localization'
    field :errors, [String], null: false, description: 'List of errors'

    def resolve(order_id:)
      current_user = context[:current_user]
      return error_response('UNAUTHORIZED') unless current_user

      order = current_user.orders.find_by(id: order_id)
      return error_response('ORDER_NOT_FOUND') unless order

      validation_error = validate_order_for_payment(order)
      return validation_error if validation_error

      create_payment_for_order(order)
    end

    private

    def validate_order_for_payment(order)
      return error_response('ORDER_NOT_PAYABLE', "order status: #{order.status}") unless order.pending?
      return error_response('PAYMENT_ALREADY_EXISTS') if order.payment_pending? || order.payment_completed?

      nil
    end

    def create_payment_for_order(order)
      comgate_service = ComgateService.new
      result = comgate_service.create_payment(order)

      if result[:success]
        update_order_with_payment(order, result)
        create_success_response(result)
      else
        Rails.logger.error "Payment creation failed for order #{order.id}: #{result[:error]}"
        error_response('PAYMENT_CREATION_FAILED', result[:error])
      end
    rescue StandardError => e
      Rails.logger.error "Payment creation error for order #{order.id}: #{e.message}"
      error_response('INTERNAL_ERROR', e.message)
    end

    def update_order_with_payment(order, result)
      order.update!(
        payment_id: result[:payment_id],
        payment_url: result[:payment_url],
        payment_status: :payment_pending
      )
      Rails.logger.info "Payment created for order #{order.id}: #{result[:payment_id]}"
    end

    def create_success_response(result)
      {
        success: true,
        payment_url: result[:payment_url],
        payment_id: result[:payment_id],
        error_code: nil,
        errors: []
      }
    end

    def error_response(code, message = nil)
      {
        success: false,
        payment_url: nil,
        payment_id: nil,
        error_code: code,
        errors: message ? [message] : []
      }
    end
  end
end
