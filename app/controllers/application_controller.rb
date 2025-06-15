# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from JWT::DecodeError, with: :handle_unauthorized
  rescue_from JWT::ExpiredSignature, with: :handle_unauthorized
end
