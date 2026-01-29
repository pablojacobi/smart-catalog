# frozen_string_literal: true

# Ensure Devise mappings are available in tests
# Routes need to be processed for Devise to register its mappings
# This is normally done during Rails initialization, but in some cases
# (like with Spring or certain Docker setups) it may not happen in time.

if Devise.mappings.empty?
  # Force route processing to register Devise mappings
  # We use routes.routes to trigger lazy loading instead of reload_routes!
  # which can cause FrozenError in production-like environments
  Rails.application.routes.routes
end
