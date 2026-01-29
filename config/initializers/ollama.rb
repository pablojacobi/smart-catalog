# frozen_string_literal: true

# Ollama Local AI Configuration
Rails.application.config.ollama = {
  base_url: ENV.fetch('OLLAMA_BASE_URL', 'http://ollama:11434'),
  model: ENV.fetch('OLLAMA_MODEL', 'llama3.2'),
  embedding_model: ENV.fetch('OLLAMA_EMBEDDING_MODEL', 'nomic-embed-text'),
  timeout: ENV.fetch('OLLAMA_TIMEOUT', 300).to_i
}
