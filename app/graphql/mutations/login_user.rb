# frozen_string_literal: true

module Mutations
  class LoginUser < BaseMutation
    description 'Authenticate user and return JWT token'

    argument :email, String, required: true, description: 'User email'
    argument :password, String, required: true, description: 'User password'

    field :user, Types::UserType, null: true, description: 'Authenticated user'
    field :token, String, null: true, description: 'JWT token for authentication'
    field :errors, [String], null: false, description: 'List of errors'

    def resolve(email:, password:)
      user = User.find_by(email: email.downcase.strip)

      if user&.valid_password?(password)
        token = generate_jwt_token(user)

        {
          user: user,
          token: token,
          errors: []
        }
      else
        {
          user: nil,
          token: nil,
          errors: ['Invalid email or password']
        }
      end
    end

    private

    def generate_jwt_token(user)
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
  end
end
