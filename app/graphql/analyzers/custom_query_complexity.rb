# frozen_string_literal: true

module Analyzers
  class CustomQueryComplexity < GraphQL::Analysis::AST::QueryComplexity
    def result
      complexity = super
      check_complexity_threshold(complexity)
      complexity
    rescue StandardError => e
      handle_analyzer_error(e)
      super
    end

    private

    def check_complexity_threshold(complexity)
      threshold = determine_complexity_threshold
      return unless complexity > threshold

      log_high_complexity_warning(complexity, threshold)
    end

    def determine_complexity_threshold
      return Float::INFINITY if staff_user?

      config_key = if Rails.env.production?
                     :complexity_warning_threshold_production
                   else
                     :complexity_warning_threshold_development
                   end

      Rails.application.config.graphql.public_send(config_key)
    end

    def staff_user?
      query.context[:current_user]&.staff?
    end

    def log_high_complexity_warning(complexity, threshold)
      message = "High complexity GraphQL query detected: #{complexity} (threshold: #{threshold})"
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
      Rails.logger.error("Error in CustomQueryComplexity analyzer: #{error.message}")
    end
  end
end
