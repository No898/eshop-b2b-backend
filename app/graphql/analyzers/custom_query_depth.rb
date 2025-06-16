# frozen_string_literal: true

module Analyzers
  class CustomQueryDepth < GraphQL::Analysis::AST::QueryDepth
    def result
      depth = super
      check_depth_threshold(depth)
      depth
    rescue StandardError => e
      handle_analyzer_error(e)
      super
    end

    private

    def check_depth_threshold(depth)
      threshold = determine_depth_threshold
      return unless depth > threshold

      log_high_depth_warning(depth, threshold)
    end

    def determine_depth_threshold
      return Float::INFINITY if staff_user?

      config_key = if Rails.env.production?
                     :depth_warning_threshold_production
                   else
                     :depth_warning_threshold_development
                   end

      Rails.application.config.graphql.public_send(config_key)
    end

    def staff_user?
      query.context[:current_user]&.staff?
    end

    def log_high_depth_warning(depth, threshold)
      message = "Deep GraphQL query detected: #{depth} (threshold: #{threshold})"
      Rails.logger.warn(message)

      log_security_event(message) if should_log_security_events?
    end

    def should_log_security_events?
      Rails.env.production? && Rails.application.config.graphql.log_security_events
    end

    def log_security_event(message)
      user_id = query.context[:current_user]&.id || 'anonymous'
      Rails.logger.error("[SECURITY] #{message} | User: #{user_id}")
    end

    def handle_analyzer_error(error)
      Rails.logger.error("Error in CustomQueryDepth analyzer: #{error.message}")
    end
  end
end
