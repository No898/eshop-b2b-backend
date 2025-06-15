# frozen_string_literal: true

# Rack::Attack rate limiting configuration

return unless Rails.application.config.security.enable_rate_limiting

module Rack
  class Attack
    # SECURITY: Configure Redis for production, memory for development
    Rack::Attack.cache.store = if Rails.env.production?
                                 ActiveSupport::Cache::RedisCacheStore.new(
                                   url: ENV['REDIS_URL'] || 'redis://localhost:6379/1'
                                 )
                               else
                                 ActiveSupport::Cache::MemoryStore.new
                               end

    # SECURITY: Basic rate limiting for all requests
    throttle('requests by ip', limit: Rails.application.config.security.max_requests_per_minute, period: 1.minute, &:ip)

    # SECURITY: Stricter rate limiting for GraphQL endpoint
    throttle('graphql by ip', limit: Rails.application.config.security.max_graphql_requests_per_minute, period: 1.minute) do |request|
      request.ip if request.path == '/graphql'
    end

    # SECURITY: Block obviously malicious requests
    blocklist('block sql injection attempts') do |request|
      request.query_string =~ /(;|\s)(drop|delete|update|insert)\s/i ||
        request.path =~ /(;|\s)(drop|delete|update|insert)\s/i
    end

    # SECURITY: Block XSS attempts
    blocklist('block xss attempts') do |request|
      request.query_string =~ /<script|javascript:|vbscript:|onload=|onerror=/i ||
        request.path =~ /<script|javascript:|vbscript:|onload=|onerror=/i
    end

    # SECURITY: Aggressive limiting for potential introspection queries
    throttle('introspection attempts', limit: 5, period: 1.hour) do |request|
      if request.path == '/graphql' && request.post?
        body = request.body.read
        request.body.rewind

        request.ip if body.include?('__schema') || body.include?('__type')
      end
    end

    # SECURITY: Rate limit authentication endpoints more strictly
    throttle('auth by ip', limit: 10, period: 5.minutes) do |request|
      if request.path == '/graphql' && request.post?
        body = request.body.read
        request.body.rewind

        request.ip if body.include?('loginUser') || body.include?('registerUser')
      end
    end

    # SECURITY: Custom response for throttled requests
    self.throttled_response = lambda do |env|
      Rails.logger.warn("Rate limit exceeded for IP: #{env['REMOTE_ADDR']}")

      [429,
       { 'Content-Type' => 'application/json' },
       [{ error: 'Too Many Requests', message: 'Příliš mnoho požadavků. Zkuste to za chvíli.', code: 'RATE_LIMITED' }.to_json]]
    end

    # SECURITY: Custom response for blocked requests
    self.blocklisted_response = lambda do |env|
      Rails.logger.error("Malicious request blocked from IP: #{env['REMOTE_ADDR']}")

      [403,
       { 'Content-Type' => 'application/json' },
       [{ error: 'Forbidden', message: 'Požadavek byl blokován', code: 'BLOCKED' }.to_json]]
    end
  end
end

# LOGGING: Log rate limiting events
ActiveSupport::Notifications.subscribe('rack.attack') do |_name, _start, _finish, _request_id, req|
  Rails.logger.warn("Rack::Attack: #{req.env['rack.attack.match_type']} #{req.env['rack.attack.matched']} from #{req.ip}")
end
