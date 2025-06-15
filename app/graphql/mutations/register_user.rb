# frozen_string_literal: true

module Mutations
  class RegisterUser < BaseMutation
    description "Registrovat nového uživatele"

    # Arguments
    argument :email, String, required: true, description: "Email uživatele"
    argument :password, String, required: true, description: "Heslo uživatele"
    argument :password_confirmation, String, required: true, description: "Potvrzení hesla"
    argument :company_name, String, required: false, description: "Název firmy (pro B2B zákazníky)"
    argument :vat_id, String, required: false, description: "DIČ (pro B2B zákazníky)"

    # Return fields
    field :user, Types::UserType, null: true, description: "Vytvořený uživatel"
    field :token, String, null: true, description: "JWT token pro autentizaci"
    field :errors, [String], null: false, description: "Seznam chyb"

    def resolve(email:, password:, password_confirmation:, company_name: nil, vat_id: nil)
      user = User.new(
        email: email.downcase.strip,
        password: password,
        password_confirmation: password_confirmation,
        company_name: company_name&.strip,
        vat_id: vat_id&.strip,
        role: :customer # Defaultně jsou všichni customer, admin se musí nastavit ručně
      )

      if user.save
        # Generujeme JWT token pro okamžité přihlášení
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
          errors: user.errors.full_messages
        }
      end
    end

    private

    def generate_jwt_token(user)
      # Použijeme Devise JWT pro generování tokenu
      jwt_payload = { sub: user.id, iat: Time.current.to_i }
      Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    rescue => e
      Rails.logger.error("Chyba při generování JWT: #{e.message}")
      nil
    end
  end
end 