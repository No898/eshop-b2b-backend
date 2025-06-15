# frozen_string_literal: true

module GraphqlErrorHandling
  extend ActiveSupport::Concern

  included do
    # ERROR HANDLING: Enhanced error handling with security logging
    rescue_from(StandardError) do |err, _obj, _args, ctx, field|
      Rails.logger.error("GraphQL Error in #{field&.path}: #{err.class} - #{err.message}")
      Rails.logger.error(err.backtrace.join("\n")) if Rails.env.development?

      # Log security-relevant errors if enabled
      if Rails.application.config.graphql.log_security_events
        jwt_error = err.is_a?(JWT::DecodeError) || err.is_a?(JWT::ExpiredSignature)
        if jwt_error
          Rails.logger.warn("GraphQL Authentication failed: #{err.message} - IP: #{ctx[:request]&.remote_ip}")
        end
      end

      # Don't leak internal errors in production unless configured
      show_detailed_errors = Rails.env.development? || Rails.application.config.graphql.detailed_errors_in_production

      if show_detailed_errors
        # In development or when detailed errors enabled, show full error details
        GraphQL::ExecutionError.new("#{err.class}: #{err.message}")
      else
        # Production with secure error messages
        case err
        when ActiveRecord::RecordNotFound
          GraphQL::ExecutionError.new('Požadovaný záznam nebyl nalezen')
        when JWT::DecodeError, JWT::ExpiredSignature
          GraphQL::ExecutionError.new('Neplatný nebo expirovaný přístupový token')
        when Pundit::NotAuthorizedError
          GraphQL::ExecutionError.new('Nemáte oprávnění k této operaci')
        when ActiveRecord::RecordInvalid
          GraphQL::ExecutionError.new("Neplatná data: #{err.record.errors.full_messages.join(', ')}")
        when ActionController::ParameterMissing
          GraphQL::ExecutionError.new('Chybějící povinný parametr')
        when ArgumentError
          GraphQL::ExecutionError.new('Neplatné argumenty')
        else
          Rails.logger.error("Unhandled GraphQL error: #{err.class} - #{err.message}")
          GraphQL::ExecutionError.new('Došlo k neočekávané chybě')
        end
      end
    end
  end
end
