# frozen_string_literal: true

Rails.application.configure do
  config.graphql = ActiveSupport::OrderedOptions.new

  # Security limits for development
  config.graphql.max_complexity_development = 100
  config.graphql.max_depth_development = 15
  config.graphql.max_query_tokens_development = 10_000
  config.graphql.max_page_size_development = 100
  config.graphql.complexity_warning_threshold_development = 50
  config.graphql.depth_warning_threshold_development = 10

  # Security limits for production
  config.graphql.max_complexity_production = 50
  config.graphql.max_depth_production = 10
  config.graphql.max_query_tokens_production = 5_000
  config.graphql.max_page_size_production = 50
  config.graphql.complexity_warning_threshold_production = 25
  config.graphql.depth_warning_threshold_production = 7

  # Security features
  config.graphql.enable_introspection_in_production = false
  config.graphql.log_security_events = true
end
