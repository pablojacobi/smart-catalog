# frozen_string_literal: true

# Ensure Devise mappings are available in tests
# This file is loaded automatically by rails_helper.rb

RSpec.configure do |config|
  config.before(:suite) do
    # Force reload routes to ensure Devise mappings are available
    # This is needed when using Spring in development
    Rails.application.reload_routes! if Devise.mappings.empty?
  end
end
