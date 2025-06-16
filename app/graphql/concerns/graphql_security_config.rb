# frozen_string_literal: true

module GraphqlSecurityConfig
  extend ActiveSupport::Concern

  included do
    # SECURITY: Disable introspection in production - no one should see our API structure
    unless Rails.env.development? || Rails.application.config.graphql.enable_introspection_in_production
      disable_introspection_entry_points
    end

    # SECURITY: Query complexity limits to prevent DoS attacks
    # Každý field má "cost", celková query nesmí přesáhnout limit
    max_complexity(production_or_development_config(:max_complexity))
    max_depth(production_or_development_config(:max_depth))

    # SECURITY: Limit query size to prevent massive queries
    max_query_string_tokens(production_or_development_config(:max_query_tokens))

    # SECURITY: Enable query analysis for monitoring
    query_analyzer(Analyzers::CustomQueryComplexity)
    query_analyzer(Analyzers::CustomQueryDepth)

    # SECURITY: Stop validating when it encounters too many errors
    validate_max_errors 100

    # SECURITY: Default pagination limit
    default_max_page_size(production_or_development_config(:max_page_size))

    # SECURITY: Query timeout protection
    query_execution_strategy(GraphQL::Execution::Interpreter)
  end

  class_methods do
    def production_or_development_config(setting_name)
      config = Rails.application.config.graphql
      if Rails.env.production?
        config.public_send("#{setting_name}_production")
      else
        config.public_send("#{setting_name}_development")
      end
    end
  end
end
