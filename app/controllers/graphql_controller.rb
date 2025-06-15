# frozen_string_literal: true

class GraphqlController < ApplicationController
  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: current_user,
      request: request # For security logging
    }
    result = LooteaB2bBackendSchema.execute(query, variables: variables, context: context,
                                                   operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = authenticate_user_from_token
  end

  def authenticate_user_from_token
    token = extract_token_from_header
    JwtService.extract_user_from_token(token)
  end

  def extract_token_from_header
    header = request.headers['Authorization']
    return nil unless header&.starts_with?('Bearer ')

    header.split.last
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      parse_string_variables(variables_param)
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def parse_string_variables(variables_string)
    if variables_string.present?
      JSON.parse(variables_string) || {}
    else
      {}
    end
  end

  def handle_error_in_development(exception)
    logger.error exception.message
    logger.error exception.backtrace.join("\n")

    render json: { errors: [{ message: exception.message, backtrace: exception.backtrace }], data: {} },
           status: :internal_server_error
  end
end
