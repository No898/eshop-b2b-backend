# frozen_string_literal: true

class GraphqlController < ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  protect_from_forgery with: :null_session

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      # Přidáme current_user do kontextu pro GraphQL
      current_user: current_user
    }
    result = LooteaB2bBackendSchema.execute(query, variables: variables, context: context,
                                                   operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  # JWT autentizace z Authorization headeru
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = authenticate_user_from_token
  end

  def authenticate_user_from_token
    token = extract_token_from_header
    return nil unless token

    begin
      # Dekódujeme JWT token pomocí Devise JWT
      decoded_token = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key, true,
                                 { algorithm: 'HS256' })
      user_id = decoded_token.first['sub']
      User.find_by(id: user_id)
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.warn("JWT autentizace selhala: #{e.message}")
      nil
    end
  end

  def extract_token_from_header
    header = request.headers['Authorization']
    return nil unless header

    # Očekáváme formát: "Bearer <token>"
    token = header.split.last
    token if header.starts_with?('Bearer ')
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
