# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  # Caching
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.cache_store = :memory_store
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  # Active Storage
  config.active_storage.service = :local if defined?(ActiveStorage)

  # Logging
  config.log_level = ENV.fetch('LOG_LEVEL', 'debug').to_sym
  config.log_tags = [:request_id]

  # Raise on missing translations
  config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names
  config.action_view.annotate_rendered_view_with_filenames = true
end
