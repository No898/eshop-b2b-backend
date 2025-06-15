# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_user!

  # SECURITY: Exception handling for non-GraphQL endpoints only
  # (GraphQL errors are handled in GraphQL schema)
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found, unless: :graphql_request?
  rescue_from JWT::DecodeError, with: :handle_unauthorized, unless: :graphql_request?
  rescue_from JWT::ExpiredSignature, with: :handle_unauthorized, unless: :graphql_request?
  rescue_from ActionController::ParameterMissing, with: :handle_bad_request, unless: :graphql_request?

  private

  def handle_not_found(exception = nil)
    Rails.logger.warn "Resource not found: #{exception&.message}"
    render json: {
      error: 'Not Found',
      message: 'Požadovaný záznam nebyl nalezen',
      code: 'NOT_FOUND'
    }, status: :not_found
  end

  def handle_unauthorized(exception = nil)
    Rails.logger.warn "Unauthorized access: #{exception&.message}"
    render json: {
      error: 'Unauthorized',
      message: 'Neplatný nebo expirovaný přístupový token',
      code: 'UNAUTHORIZED'
    }, status: :unauthorized
  end

  def handle_bad_request(exception)
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
