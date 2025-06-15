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
        token = JwtService.generate_token(user)

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
  end
end
