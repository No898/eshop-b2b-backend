# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_user!

  # SECURITY: Exception handling for non-GraphQL endpoints only
  # (GraphQL errors are handled in GraphQL schema)
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from JWT::DecodeError, with: :handle_unauthorized
  rescue_from JWT::ExpiredSignature, with: :handle_unauthorized
  rescue_from ActionController::ParameterMissing, with: :handle_bad_request

  private

  def handle_not_found(exception = nil)
    # Skip if GraphQL request - let GraphQL handle its own errors
    return if graphql_request?

    Rails.logger.warn "Resource not found: #{exception&.message}"
    render json: {
      error: 'Not Found',
      message: 'Požadovaný záznam nebyl nalezen',
      code: 'NOT_FOUND'
    }, status: :not_found
  end

  def handle_unauthorized(exception = nil)
    # Skip if GraphQL request - let GraphQL handle its own errors
    return if graphql_request?

    Rails.logger.warn "Unauthorized access: #{exception&.message}"
    render json: {
      error: 'Unauthorized',
      message: 'Neplatný nebo expirovaný přístupový token',
      code: 'UNAUTHORIZED'
    }, status: :unauthorized
  end

  def handle_bad_request(exception)
    # Skip if GraphQL request - let GraphQL handle its own errors
    return if graphql_request?

    Rails.logger.warn "Bad request: #{exception.message}"
    render json: {
      error: 'Bad Request',
      message: 'Chybějící povinný parametr',
      code: 'BAD_REQUEST'
    }, status: :bad_request
  end

  # SECURITY: Check if current request is to GraphQL endpoint
  def graphql_request?
    request.path == '/graphql'
  end

  # SECURITY: Ensure user is admin
  def ensure_admin!
    return if current_user&.admin?

    Rails.logger.warn "Admin access denied for user: #{current_user&.id}"
    render json: {
      error: 'Forbidden',
      message: 'Nemáte oprávnění k této operaci',
      code: 'FORBIDDEN'
    }, status: :forbidden
  end
end
