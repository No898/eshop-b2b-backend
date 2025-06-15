# frozen_string_literal: true

require_relative 'comgate_service/http_client'
require_relative 'comgate_service/response_parser'

# app/services/comgate_service.rb
class ComgateService
  include ComgateService::HttpClient
  include ComgateService::ResponseParser

  class ComgateError < StandardError; end
  class ConfigurationError < ComgateError; end
  class ApiError < ComgateError; end

  BASE_URL = ENV.fetch('COMGATE_BASE_URL', 'https://payments.comgate.cz/v2.0').freeze

  def initialize
    validate_configuration!

    @merchant_id = credentials[:merchant_id]
    @secret = credentials[:secret]
    @test_mode = Rails.env.local?
  end

  def create_payment(order)
    validate_order!(order)

    payload = build_payment_payload(order)
    response = make_api_request('POST', '/payment.json', payload)
    parse_payment_response(response)
  rescue ComgateError => e
    Rails.logger.error "Comgate payment creation failed: #{e.message}"
    { success: false, error: e.message }
  end

  def verify_payment(payment_id)
    raise ArgumentError, 'Payment ID cannot be blank' if payment_id.blank?

    response = make_api_request('GET', "/payment/transId/#{payment_id}.json")
    parse_verification_response(response)
  rescue ComgateError => e
    Rails.logger.error "Comgate payment verification failed: #{e.message}"
    { success: false, error: e.message }
  end

  def cancel_payment(payment_id)
    raise ArgumentError, 'Payment ID cannot be blank' if payment_id.blank?

    response = make_api_request('DELETE', "/payment/transId/#{payment_id}.json")
    { success: response['code'].zero?, message: response['message'] }
  rescue ComgateError => e
    Rails.logger.error "Comgate payment cancellation failed: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def validate_configuration!
    missing = []
    missing << 'merchant_id' if credentials[:merchant_id].blank?
    missing << 'secret' if credentials[:secret].blank?

    return unless missing.any?

    raise ConfigurationError, "Missing Comgate credentials: #{missing.join(', ')}"
  end

  def validate_order!(order)
    raise ArgumentError, 'Order cannot be nil' if order.nil?
    raise ArgumentError, 'Order must have positive total' if order.total_cents <= 0
    raise ArgumentError, 'Order must have currency' if order.currency.blank?
    raise ArgumentError, 'Order must have user with email' if order.user&.email.blank?
  end

  def credentials
    @credentials ||= Rails.application.credentials.comgate || {}
  end

  def build_payment_payload(order)
    {
      test: @test_mode,
      price: order.total_cents,
      curr: order.currency,
      label: "Order ##{order.id}",
      refId: order.id.to_s,
      method: 'ALL',
      email: order.user.email,
      fullName: order.user.company_name || order.user.email,
      lang: 'cs',
      country: 'CZ'
    }
  end
end
