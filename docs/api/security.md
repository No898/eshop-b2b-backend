# 🔒 GraphQL Security Guide

Komplexní bezpečnostní dokumentace pro GraphQL API v Lootea B2B Backend. Tato příručka pokrývá všechny security best practices a implementované ochranné mechanismy.

## 📋 Obsah
- [🛡️ Implementované ochrany](#️-implementované-ochrany)
- [🔐 Autentizace a autorizace](#-autentizace-a-autorizace)
- [⚡ Rate limiting](#-rate-limiting)
- [🔍 Query analysis](#-query-analysis)
- [📊 Monitoring](#-monitoring)
- [🚨 Incident response](#-incident-response)

---

## 🛡️ Implementované ochrany

### Query Depth Limiting
```ruby
# app/graphql/analyzers/custom_query_depth.rb
class CustomQueryDepth < GraphQL::Analysis::QueryDepth
  def max_depth
    Rails.env.production? ? 8 : 15
  end

  def handle_result(result)
    if result > max_depth
      GraphQL::AnalysisError.new("Query exceeds maximum depth of #{max_depth}")
    end
  end
end
```

### Query Complexity Analysis
```ruby
# app/graphql/analyzers/custom_query_complexity.rb
class CustomQueryComplexity < GraphQL::Analysis::QueryComplexity
  def max_complexity
    Rails.env.production? ? 200 : 1000
  end

  def handle_result(result)
    if result > max_complexity
      GraphQL::AnalysisError.new("Query exceeds maximum complexity of #{max_complexity}")
    end
  end
end
```

### Schema Configuration
```ruby
# app/graphql/lootea_b2b_backend_schema.rb
class LooteaB2bBackendSchema < GraphQL::Schema
  # Security analyzers
  query_analyzer(CustomQueryDepth)
  query_analyzer(CustomQueryComplexity)

  # Timeout protection
  max_query_string_tokens(5000)
  default_max_page_size(50)

  # Introspection disabled in production
  disable_introspection_entry_points if Rails.env.production?

  # Error handling
  rescue_from(ActiveRecord::RecordNotFound) do |err, obj, args, ctx, field|
    GraphQL::ExecutionError.new("Record not found", extensions: {"code" => "NOT_FOUND"})
  end
end
```

---

## 🔐 Autentizace a autorizace

### JWT Token Validation
```ruby
# app/controllers/graphql_controller.rb
class GraphqlController < ApplicationController
  before_action :authenticate_user_from_token!

  private

  def authenticate_user_from_token!
    token = request.headers['Authorization']&.split(' ')&.last
    return unless token

    begin
      payload = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key, true, algorithm: 'HS256')
      @current_user = User.find(payload[0]['sub'])
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
      @current_user = nil
    end
  end

  def current_user
    @current_user
  end
end
```

### Authorization Patterns
```ruby
# app/graphql/mutations/base_mutation.rb
class BaseMutation < GraphQL::Schema::RelayClassicMutation
  def authorize_admin!
    raise GraphQL::ExecutionError, "Admin access required" unless current_user&.admin?
  end

  def authorize_user!
    raise GraphQL::ExecutionError, "Authentication required" unless current_user
  end

  def authorize_owner!(resource)
    unless current_user&.admin? || resource.user == current_user
      raise GraphQL::ExecutionError, "Access denied"
    end
  end
end
```

### Field-Level Authorization
```ruby
# app/graphql/types/user_type.rb
class UserType < Types::BaseObject
  field :email, String, null: false
  field :vat_id, String, null: true do
    # Only user themselves or admin can see VAT ID
    authorize ->(obj, args, ctx) {
      ctx[:current_user]&.admin? || ctx[:current_user] == obj
    }
  end
end
```

---

## ⚡ Rate Limiting

### Rack::Attack Configuration
```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Throttle GraphQL requests
  throttle('graphql/ip', limit: 100, period: 1.hour) do |req|
    req.ip if req.path == '/graphql'
  end

  # Throttle login attempts
  throttle('login/email', limit: 5, period: 20.minutes) do |req|
    if req.path == '/graphql' && req.post?
      body = JSON.parse(req.body.read) rescue {}
      if body['query']&.include?('loginUser')
        # Extract email from variables or query
        email = extract_email_from_query(body)
        email&.downcase
      end
    end
  end

  # Block suspicious IPs
  blocklist('block suspicious') do |req|
    Rack::Attack::Fail2Ban.filter("fail2ban-#{req.ip}", maxretry: 10, findtime: 10.minutes, bantime: 1.hour) do
      req.path == '/graphql' && suspicious_query?(req)
    end
  end
end
```

### Custom Rate Limiting in GraphQL
```ruby
# app/graphql/concerns/graphql_rate_limiting.rb
module GraphqlRateLimiting
  extend ActiveSupport::Concern

  def rate_limit!(key, limit: 10, period: 1.minute)
    cache_key = "rate_limit:#{context[:current_user]&.id || context[:request].ip}:#{key}"
    current_count = Rails.cache.read(cache_key) || 0

    if current_count >= limit
      raise GraphQL::ExecutionError.new(
        "Rate limit exceeded. Try again in #{period} seconds.",
        extensions: { "code" => "RATE_LIMITED" }
      )
    end

    Rails.cache.write(cache_key, current_count + 1, expires_in: period)
  end
end
```

---

## 🔍 Query Analysis

### Dangerous Query Detection
```ruby
# app/graphql/analyzers/dangerous_query_analyzer.rb
class DangerousQueryAnalyzer < GraphQL::Analysis::Analyzer
  def analyze_query(query, query_type)
    @dangerous_patterns = []
    super
  end

  def on_enter_field(node, parent, visitor)
    # Detect N+1 potential
    if node.name == "orders" && parent_has_loop?(parent)
      @dangerous_patterns << "Potential N+1 query detected"
    end

    # Detect expensive operations
    if expensive_field?(node.name)
      @dangerous_patterns << "Expensive operation: #{node.name}"
    end
  end

  def result
    if @dangerous_patterns.any? && Rails.env.production?
      GraphQL::AnalysisError.new("Dangerous query patterns: #{@dangerous_patterns.join(', ')}")
    end
  end

  private

  def expensive_field?(field_name)
    %w[calculate_complex_metrics generate_report export_data].include?(field_name)
  end
end
```

### Query Whitelisting
```ruby
# app/graphql/query_whitelist.rb
class QueryWhitelist
  ALLOWED_QUERIES = {
    production: [
      "GetProducts",
      "GetProduct",
      "CurrentUser",
      "MyOrders",
      "LoginUser",
      "RegisterUser",
      "CreateOrder"
    ],
    development: :all
  }.freeze

  def self.allowed?(query_name)
    return true if Rails.env.development? && ALLOWED_QUERIES[:development] == :all

    ALLOWED_QUERIES[Rails.env.to_sym]&.include?(query_name)
  end
end
```

---

## 📊 Monitoring

### GraphQL Logging
```ruby
# app/graphql/concerns/graphql_logging.rb
module GraphqlLogging
  extend ActiveSupport::Concern

  def log_query_execution(query, variables, context)
    start_time = Time.current

    result = yield

    duration = Time.current - start_time

    Rails.logger.info({
      event: 'graphql_query',
      query_name: query.operation_name,
      duration: duration,
      user_id: context[:current_user]&.id,
      ip: context[:request].ip,
      complexity: query.complexity,
      depth: query.depth
    }.to_json)

    # Alert on slow queries
    if duration > 5.seconds
      Rails.logger.warn("Slow GraphQL query: #{query.operation_name} (#{duration}s)")
    end

    result
  end
end
```

### Security Metrics
```ruby
# app/models/security_event.rb
class SecurityEvent < ApplicationRecord
  enum event_type: {
    failed_login: 0,
    rate_limit_hit: 1,
    suspicious_query: 2,
    unauthorized_access: 3,
    query_complexity_exceeded: 4
  }

  scope :recent, -> { where(created_at: 1.hour.ago..) }
  scope :by_ip, ->(ip) { where(ip_address: ip) }

  def self.log_event(type, details = {})
    create!(
      event_type: type,
      ip_address: details[:ip],
      user_id: details[:user_id],
      details: details.except(:ip, :user_id)
    )
  end
end
```

---

## 🚨 Incident Response

### Automated Blocking
```ruby
# app/services/security_response_service.rb
class SecurityResponseService
  def self.handle_security_event(event_type, context = {})
    case event_type
    when :multiple_failed_logins
      block_ip_temporarily(context[:ip])
      notify_security_team(event_type, context)

    when :query_complexity_attack
      block_ip_temporarily(context[:ip])
      disable_complex_queries_temporarily

    when :suspicious_query_pattern
      log_for_analysis(context[:query])
      rate_limit_user(context[:user_id]) if context[:user_id]
    end
  end

  private

  def self.block_ip_temporarily(ip)
    Rails.cache.write("blocked_ip:#{ip}", true, expires_in: 1.hour)
  end

  def self.notify_security_team(event_type, context)
    # Integration with monitoring service (e.g., Sentry, Slack)
    Rails.logger.error({
      alert: 'Security incident',
      event_type: event_type,
      context: context,
      timestamp: Time.current
    }.to_json)
  end
end
```

### Circuit Breaker Pattern
```ruby
# app/graphql/concerns/circuit_breaker.rb
module CircuitBreaker
  extend ActiveSupport::Concern

  def with_circuit_breaker(key, failure_threshold: 5, timeout: 30.seconds)
    circuit_key = "circuit_breaker:#{key}"
    failure_count = Rails.cache.read("#{circuit_key}:failures") || 0
    last_failure = Rails.cache.read("#{circuit_key}:last_failure")

    # Circuit is open (blocked)
    if failure_count >= failure_threshold
      if last_failure && Time.current - last_failure < timeout
        raise GraphQL::ExecutionError.new(
          "Service temporarily unavailable",
          extensions: { "code" => "SERVICE_UNAVAILABLE" }
        )
      else
        # Try to reset circuit
        Rails.cache.delete("#{circuit_key}:failures")
        Rails.cache.delete("#{circuit_key}:last_failure")
      end
    end

    begin
      yield
    rescue => error
      # Record failure
      Rails.cache.write("#{circuit_key}:failures", failure_count + 1, expires_in: timeout)
      Rails.cache.write("#{circuit_key}:last_failure", Time.current, expires_in: timeout)
      raise error
    end
  end
end
```

---

## 🔧 Security Configuration Checklist

### Production Deployment
- [ ] **Introspection disabled** - `disable_introspection_entry_points`
- [ ] **HTTPS only** - SSL/TLS certificates configured
- [ ] **CORS properly configured** - Only allowed origins
- [ ] **Rate limiting active** - Rack::Attack configured
- [ ] **Query depth/complexity limits** - Appropriate for your use case
- [ ] **JWT secrets rotated** - Strong, unique secrets
- [ ] **Database connections encrypted** - SSL enabled
- [ ] **Logging configured** - Security events tracked
- [ ] **Monitoring active** - Alerts for suspicious activity

### Regular Security Tasks
- [ ] **Review query logs** - Weekly analysis of slow/complex queries
- [ ] **Update dependencies** - Monthly security updates
- [ ] **Rotate JWT secrets** - Quarterly rotation
- [ ] **Security audit** - Annual penetration testing
- [ ] **Backup verification** - Monthly restore tests

---

## 📚 Related Documentation
- **[GraphQL API Reference](./graphql.md)** - Complete API documentation
- **[Authentication Guide](../components/auth.md)** - Frontend JWT implementation
- **[Error Handling](../components/errors.md)** - Secure error handling patterns

---

*Dokumentace aktualizována: 18.6.2025*