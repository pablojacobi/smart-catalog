# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.1'

# Rails
gem 'rails', '~> 8.1'

# Database
gem 'neighbor', '~> 0.5' # pgvector support
gem 'pg', '~> 1.5'

# Server
gem 'puma', '~> 6.5'

# HTTP Client
gem 'faraday', '~> 2.12'
gem 'faraday-retry', '~> 2.2'

# JSON Serialization
gem 'blueprinter', '~> 1.1'
gem 'oj', '~> 3.16'

# Utilities
gem 'bootsnap', require: false
gem 'tzinfo-data', platforms: %i[windows jruby]

# CORS
gem 'rack-cors', '~> 2.0'

group :development, :test do
  gem 'brakeman', require: false
  gem 'debug', platforms: %i[mri windows]
  gem 'factory_bot_rails', '~> 6.4'
  gem 'faker', '~> 3.5'
  gem 'rspec-rails', '~> 7.1'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'shoulda-matchers', '~> 6.4'
  gem 'simplecov', require: false
  gem 'webmock', '~> 3.24'
end
