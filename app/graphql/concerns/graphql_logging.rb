# frozen_string_literal: true

module GraphqlLogging
  extend ActiveSupport::Concern

  class_methods do
    # LOGGING: Enhanced logging for security monitoring
    def execute(query_str = nil, **kwargs)
      log_graphql_request(kwargs) if should_log_requests?(kwargs)
      log_introspection_attempt(query_str, kwargs) if introspection_attempt?(query_str, kwargs)

      super
    end

    def should_log_requests?(kwargs)
      Rails.application.config.graphql.log_all_requests && kwargs[:context]&.dig(:request)
    end

    def log_graphql_request(kwargs)
      request = kwargs[:context][:request]
      user = kwargs[:context][:current_user]
      Rails.logger.info("GraphQL Request: #{request.remote_ip} - User: #{user&.id || 'anonymous'}")
    end

    def introspection_attempt?(query_str, kwargs)
      Rails.application.config.graphql.log_security_events &&
        kwargs[:context]&.dig(:request) &&
        (query_str&.include?('__schema') || query_str&.include?('__type'))
    end

    def log_introspection_attempt(query_str, kwargs)
      request = kwargs[:context][:request]
      Rails.logger.warn("Introspection query attempt from IP: #{request.remote_ip} - Query: #{query_str&.first(100)}")
    end
  end
end
