# frozen_string_literal: true

module Gemini
  # Service for generating text embeddings using Gemini
  class EmbeddingsService
    include CallableService

    def initialize(text)
      @text = text
      @client = ClientService.new
    end

    def call
      return [] if @text.blank?

      sanitized_text = sanitize_text(@text)
      @client.embed(sanitized_text)
    end

    private

    def sanitize_text(text)
      text.to_s
          .gsub(/\s+/, ' ')
          .strip
          .slice(0, 10_000)
    end
  end
end
