# frozen_string_literal: true

source 'https://rubygems.org'

gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'rails', '~> 8.0.2'

# JWT + auth
gem 'devise'
gem 'devise-jwt'
gem 'pundit'

# API + GraphQL
gem 'graphiql-rails', group: :development
gem 'graphql'
gem 'rack-cors'

# Security
gem 'rack-attack'
gem 'redis', '>= 4.0.1'

# Background jobs
gem 'sidekiq'

# Cache / queue - můžeš zatím nechat, pokud se chceš učit moderní Rails, ale není nutné
gem 'solid_cache'
gem 'solid_queue'

# Boot performance
gem 'bootsnap', require: false

# Debug / testing
group :development, :test do
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
end

# Code quality (senior Prague setup)
group :development do
  gem 'brakeman'
  gem 'lefthook'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
end

# Platform specifics
gem 'tzinfo-data', platforms: %i[windows jruby]

# Docker deploy: Kamal - ZATÍM NECH — teď to nepotřebuješ
# gem "kamal", require: false

# Thruster: Zbytečné pro tvůj use case (řeší caching assets, ty žádné assets nemáš)
# gem "thruster", require: false
gem 'aws-sdk-s3', '~> 1.190'
gem 'image_processing', '~> 1.2'
gem 'rspec_junit_formatter', group: :test
gem 'rspec-rails', group: %i[development test]
