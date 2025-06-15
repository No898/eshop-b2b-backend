# frozen_string_literal: true

class JwtService
  class << self
    def generate_token(user)
      payload = {
        sub: user.id,
        iat: Time.current.to_i,
        exp: 24.hours.from_now.to_i
      }

      secret_key = Rails.application.credentials.devise_jwt_secret_key ||
                   ENV['JWT_SECRET_KEY'] ||
                   'fallback_secret_key_for_development'

      JWT.encode(payload, secret_key, 'HS256')
    rescue StandardError => e
      Rails.logger.error("JWT token generation failed: #{e.message}")
      nil
    end

    def decode_token(token)
      secret_key = Rails.application.credentials.devise_jwt_secret_key ||
                   ENV['JWT_SECRET_KEY'] ||
                   'fallback_secret_key_for_development'

      decoded_token = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      decoded_token.first
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.warn("JWT token decode failed: #{e.message}")
      nil
    end

    def extract_user_from_token(token)
      return nil unless token

      decoded = decode_token(token)
      return nil unless decoded

      User.find_by(id: decoded['sub'])
    end
  end
end
