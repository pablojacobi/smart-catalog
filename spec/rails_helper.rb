# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# IMPORTANT: In local development, remove DATABASE_URL to prevent accidentally
# connecting to production (Supabase). In CI, DATABASE_URL is correctly configured
# to point to localhost test database and should be preserved.
ENV.delete('DATABASE_URL') unless ENV['CI'] || ENV['GITHUB_ACTIONS']

require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'webmock/rspec'
require 'database_cleaner/active_record'

# Load support files
Rails.root.glob('spec/support/**/*.rb').each { |f| require f }

# Force routes to load to ensure Devise mappings are available
Rails.application.reload_routes!

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = false # DatabaseCleaner handles this
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.include Devise::Test::IntegrationHelpers, type: :request

  # DatabaseCleaner configuration
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, type: :request) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  # Set default host for request specs
  config.before(:each, type: :request) do
    host! 'localhost'
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

WebMock.disable_net_connect!(allow_localhost: true)
