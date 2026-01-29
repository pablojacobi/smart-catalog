# frozen_string_literal: true

# Gemini AI Configuration
Rails.application.config.gemini = {
  api_key: ENV.fetch('GEMINI_API_KEY', nil),
  model: ENV.fetch('GEMINI_MODEL', 'gemini-2.0-flash'),
  embedding_model: ENV.fetch('GEMINI_EMBEDDING_MODEL', 'text-embedding-004'),
  base_url: 'https://generativelanguage.googleapis.com/v1',
  timeout: 60
}

# Validate in production
raise 'GEMINI_API_KEY is required in production' if Rails.env.production? && Rails.application.config.gemini[:api_key].blank?
