# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_cable/engine'

Bundler.require(*Rails.groups)

module SmartCatalog
  class Application < Rails::Application
    config.load_defaults 8.1

    # Allow both API and HTML responses
    # API controllers inherit from ActionController::API
    # HTML controllers inherit from ActionController::Base
    config.api_only = false

    # Time zone
    config.time_zone = 'UTC'

    # Autoload paths
    config.autoload_paths << Rails.root.join('app/services')
    config.autoload_paths << Rails.root.join('app/services/concerns')
    config.autoload_paths << Rails.root.join('app/queries')
    config.autoload_paths << Rails.root.join('app/blueprints')

    # Generators
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
      g.orm :active_record, primary_key_type: :uuid
    end
  end
end
