# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # Caching
  config.action_controller.perform_caching = true

  # Logging
  config.log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym
  config.log_tags = [:request_id]

  # Use default logging formatter
  config.log_formatter = ::Logger::Formatter.new

  # Log to STDOUT
  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations
  config.active_record.dump_schema_after_migration = false

  # Raise on missing callback
  config.action_controller.raise_on_missing_callback_actions = true
end
