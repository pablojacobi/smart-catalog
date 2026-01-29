# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV['CI'].present?
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = :rescuable

  # Disable host authorization completely for tests
  config.hosts.clear

  # Logging
  config.log_level = :warn

  # Raise on missing translations
  config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error on missing callback
  config.action_controller.raise_on_missing_callback_actions = true
end
