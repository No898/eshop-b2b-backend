require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LooteaB2bBackend
  class Application < Rails::Application
    config.active_record.query_log_tags_enabled = true
    config.active_record.query_log_tags = [
      # Rails query log tags:
      :application, :controller, :action, :job,
      # GraphQL-Ruby query log tags:
      current_graphql_operation: -> { GraphQL::Current.operation_name },
      current_graphql_field: -> { GraphQL::Current.field&.path },
      current_dataloader_source: -> { GraphQL::Current.dataloader_source_class },
    ]
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # SECURITY: Add security headers middleware
    if Rails.env.production?
      require 'rack/attack'
      config.middleware.use Rack::Attack
    end

    # GRAPHQL SECURITY CONFIGURATION
    # Configurable limits for different environments
    config.graphql = ActiveSupport::OrderedOptions.new

    # Query complexity limits (higher numbers = more expensive queries)
    config.graphql.max_complexity_production = ENV.fetch('GRAPHQL_MAX_COMPLEXITY', 200).to_i
    config.graphql.max_complexity_development = ENV.fetch('GRAPHQL_MAX_COMPLEXITY_DEV', 1000).to_i
    config.graphql.complexity_warning_threshold_production = ENV.fetch('GRAPHQL_COMPLEXITY_WARNING', 150).to_i
    config.graphql.complexity_warning_threshold_development = ENV.fetch('GRAPHQL_COMPLEXITY_WARNING_DEV', 800).to_i

    # Query depth limits (nesting level of queries)
    config.graphql.max_depth_production = ENV.fetch('GRAPHQL_MAX_DEPTH', 10).to_i
    config.graphql.max_depth_development = ENV.fetch('GRAPHQL_MAX_DEPTH_DEV', 15).to_i
    config.graphql.depth_warning_threshold_production = ENV.fetch('GRAPHQL_DEPTH_WARNING', 8).to_i
    config.graphql.depth_warning_threshold_development = ENV.fetch('GRAPHQL_DEPTH_WARNING_DEV', 12).to_i

    # Query size limits (number of tokens)
    config.graphql.max_query_tokens_production = ENV.fetch('GRAPHQL_MAX_TOKENS', 5000).to_i
    config.graphql.max_query_tokens_development = ENV.fetch('GRAPHQL_MAX_TOKENS_DEV', 10000).to_i

    # Pagination limits
    config.graphql.max_page_size_production = ENV.fetch('GRAPHQL_MAX_PAGE_SIZE', 50).to_i
    config.graphql.max_page_size_development = ENV.fetch('GRAPHQL_MAX_PAGE_SIZE_DEV', 100).to_i

    # Security features
    config.graphql.enable_introspection_in_production = ENV.fetch('GRAPHQL_ENABLE_INTROSPECTION', 'false') == 'true'
    config.graphql.log_security_events = ENV.fetch('GRAPHQL_LOG_SECURITY', 'true') == 'true'
    config.graphql.log_all_requests = ENV.fetch('GRAPHQL_LOG_REQUESTS', Rails.env.production? ? 'false' : 'true') == 'true'

    # Error handling
    config.graphql.detailed_errors_in_production = ENV.fetch('GRAPHQL_DETAILED_ERRORS', 'false') == 'true'

    # SECURITY: Additional security configuration
    config.security = ActiveSupport::OrderedOptions.new
    config.security.max_requests_per_minute = ENV.fetch('MAX_REQUESTS_PER_MINUTE', 60).to_i
    config.security.max_graphql_requests_per_minute = ENV.fetch('MAX_GRAPHQL_REQUESTS_PER_MINUTE', 30).to_i
    config.security.enable_rate_limiting = ENV.fetch('ENABLE_RATE_LIMITING', Rails.env.production?.to_s) == 'true'
  end
end
