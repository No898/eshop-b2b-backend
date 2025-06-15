# frozen_string_literal: true

module Webhooks
  class ComgateController < ApplicationController
    # Skip CSRF protection for webhook endpoints
    skip_before_action :verify_authenticity_token

    # Skip authentication for webhooks
    skip_before_action :authenticate_user!, if: :devise_controller?

    before_action :verify_webhook_signature
    before_action :log_webhook_request

    def receive
      result = process_webhook
      render_webhook_response(result)
    rescue StandardError => e
      handle_webhook_error(e)
    end

    private

    def process_webhook
      webhook_service = ComgateWebhookService.new(webhook_params)
      webhook_service.process
    end

    def render_webhook_response(result)
      if result[:success]
        Rails.logger.info "Comgate webhook processed successfully: #{result[:message]}"
        render json: { status: 'ok' }, status: :ok
      else
        Rails.logger.error "Comgate webhook processing failed: #{result[:error]}"
        render json: { status: 'error', message: result[:error] }, status: :unprocessable_entity
      end
    end

    def handle_webhook_error(error)
      Rails.logger.error "Comgate webhook error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      render json: { status: 'error', message: 'Internal server error' }, status: :internal_server_error
    end

    def webhook_params
      params.permit(:transId, :refId, :status, :price, :curr, :label, :method, :email, :test)
    end

    def verify_webhook_signature
      return if Rails.env.development? && !signature_verification_enabled?

      signature = request.headers['HTTP_X_SIGNATURE']
      return render_unauthorized('Missing signature') if signature.blank?

      expected_signature = calculate_expected_signature
      return render_unauthorized('Invalid signature') unless valid_signature?(signature, expected_signature)

      Rails.logger.debug 'Webhook signature verified successfully'
    end

    def signature_verification_enabled?
      Rails.application.credentials.comgate&.dig(:verify_webhooks) != false
    end

    def calculate_expected_signature
      secret = Rails.application.credentials.comgate&.dig(:secret) || ENV.fetch('COMGATE_SECRET', nil)
      return nil if secret.blank?

      # Comgate uses HMAC-SHA256 with specific parameter order
      data = build_signature_data
      OpenSSL::HMAC.hexdigest('SHA256', secret, data)
    end

    def build_signature_data
      # Comgate signature includes specific parameters in exact order
      params_for_signature = %w[transId refId status price curr label method email test]
      values = params_for_signature.map { |key| webhook_params[key].to_s }
      values.join('|')
    end

    def valid_signature?(received_signature, expected_signature)
      return false if expected_signature.nil?

      # Use secure comparison to prevent timing attacks
      ActiveSupport::SecurityUtils.secure_compare(received_signature, expected_signature)
    end

    def render_unauthorized(message)
      Rails.logger.warn "Webhook unauthorized: #{message}"
      render json: { status: 'unauthorized', message: message }, status: :unauthorized
    end

    def log_webhook_request
      Rails.logger.info "Comgate webhook received: #{webhook_params.to_json}"
      Rails.logger.debug { "Request headers: #{request.headers.to_h.select { |k, _| k.start_with?('HTTP_') }}" }
    end
  end
end
