# frozen_string_literal: true

module Mutations
  class LoginUser < BaseMutation
    description 'Přihlásit uživatele do systému'

    # Arguments
    argument :email, String, required: true, description: 'Email uživatele'
    argument :password, String, required: true, description: 'Heslo uživatele'

    # Return fields
    field :user, Types::UserType, null: true, description: 'Přihlášený uživatel'
    field :token, String, null: true, description: 'JWT token pro autentizaci'
    field :errors, [String], null: false, description: 'Seznam chyb'

    def resolve(email:, password:)
      user = User.find_by(email: email.downcase.strip)

      if user&.valid_password?(password)
        # Generujeme JWT token
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
          errors: ['Neplatný email nebo heslo']
        }
      end
    end

    private

    def generate_jwt_token(user)
      # Použijeme Devise JWT pro generování tokenu
      { sub: user.id, iat: Time.current.to_i }
      Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    rescue StandardError => e
      Rails.logger.error("Chyba při generování JWT: #{e.message}")
      nil
    end
  end
end
