# frozen_string_literal: true

class LooteaB2bBackendSchema < GraphQL::Schema
  # Include security and functionality modules
  include GraphqlSecurityConfig
  include GraphqlErrorHandling
  include GraphqlAuthorization
  include GraphqlLogging

  mutation(Types::MutationType)
  query(Types::QueryType)

  # For batch-loading (see https://graphql-ruby.org/dataloader/overview.html)
  use GraphQL::Dataloader

  # Union and Interface Resolution
  def self.resolve_type(_abstract_type, _obj, _ctx)
    # TODO: Implement this method
    # to return the correct GraphQL object type for `obj`
    raise(GraphQL::RequiredImplementationMissingError)
  end
end
