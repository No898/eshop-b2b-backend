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
    query_analyzer(GraphQL::Analysis::QueryComplexity.new do |_query, complexity_value|
      warning_threshold = if Rails.env.production?
                            Rails.application.config.graphql.complexity_warning_threshold_production
                          else
                            Rails.application.config.graphql.complexity_warning_threshold_development
                          end

      if complexity_value > warning_threshold
        message = "High complexity GraphQL query detected: #{complexity_value} (threshold: #{warning_threshold})"
        Rails.logger.warn(message)
      end
    end)

    query_analyzer(GraphQL::Analysis::QueryDepth.new do |_query, depth_value|
      warning_threshold = if Rails.env.production?
                            Rails.application.config.graphql.depth_warning_threshold_production
                          else
                            Rails.application.config.graphql.depth_warning_threshold_development
                          end

      if depth_value > warning_threshold
        Rails.logger.warn("Deep GraphQL query detected: #{depth_value} (threshold: #{warning_threshold})")
      end
    end)

    # SECURITY: Stop validating when it encounters too many errors
    validate_max_errors 100

    # SECURITY: Default pagination limit
    default_max_page_size(production_or_development_config(:max_page_size))

    # SECURITY: Query timeout protection
    query_execution_strategy(
      GraphQL::Execution::Interpreter,
      validate: Rails.env.development?
    )
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
