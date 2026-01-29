# frozen_string_literal: true

module Ai
  # Unified AI provider that switches between Ollama (local) and Gemini (cloud)
  # Use AI_PROVIDER env var to select: 'ollama' (default) or 'gemini'
  class ProviderService
    include CallableService

    def initialize
      @provider = ENV.fetch('AI_PROVIDER', 'ollama').downcase
    end

    def client
      case @provider
      when 'gemini'
        Gemini::ClientService.new
      else
        Ollama::ClientService.new
      end
    end

    def embeddings_service(text)
      case @provider
      when 'gemini'
        Gemini::EmbeddingsService.new(text)
      else
        Ollama::EmbeddingsService.new(text)
      end
    end

    def embed(text)
      embeddings_service(text).call
    end

    def generate_content(messages, **options)
      client.generate_content(messages, **options)
    end

    def stream_content(messages, **options, &)
      client.stream_content(messages, **options, &)
    end

    def provider_name
      @provider
    end

    def local?
      @provider == 'ollama'
    end

    class << self
      def instance
        @instance ||= new
      end

      delegate :client, :embed, :embeddings_service, :generate_content, :stream_content,
               :provider_name, :local?, to: :instance
    end
  end
end
