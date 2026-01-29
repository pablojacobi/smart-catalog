# frozen_string_literal: true

module Gemini
  # HTTP client for Gemini API
  # Handles authentication, retries, and error handling
  class ClientService
    include CallableService

    RETRY_ERRORS = [Faraday::TimeoutError, Faraday::ConnectionFailed].freeze
    MAX_RETRIES = 3

    def initialize
      @config = Rails.application.config.gemini
      @api_key = @config[:api_key]
      @base_url = @config[:base_url]
    end

    # Generate content (chat completion)
    def generate_content(messages, model: nil, temperature: 0.7, max_tokens: 2048)
      model ||= @config[:model]

      body = {
        contents: format_messages(messages),
        generationConfig: {
          temperature: temperature,
          maxOutputTokens: max_tokens
        }
      }

      response = post("/models/#{model}:generateContent", body)
      parse_generate_response(response)
    end

    # Generate embeddings
    def embed(text, model: nil)
      model ||= @config[:embedding_model]

      body = {
        model: "models/#{model}",
        content: {
          parts: [{ text: text.to_s[0, 10_000] }]
        }
      }

      response = post("/models/#{model}:embedContent", body)
      parse_embedding_response(response)
    end

    private

    def connection
      @connection ||= Faraday.new(url: @base_url) do |f|
        f.request :json
        f.response :json
        f.options.timeout = @config[:timeout]
        f.options.open_timeout = 10
        f.adapter Faraday.default_adapter
      end
    end

    def post(endpoint, body)
      retries = 0

      begin
        response = connection.post("#{endpoint}?key=#{@api_key}") do |req|
          req.body = body
        end

        handle_response(response)
      rescue *RETRY_ERRORS => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep(2**retries)
          retry
        end
        raise SmartCatalog::ServiceUnavailableError.new("Gemini API unavailable: #{e.message}")
      end
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 400
        raise SmartCatalog::ValidationError.new("Bad request: #{extract_error(response)}")
      when 401, 403
        raise SmartCatalog::AuthenticationError.new("Authentication failed: #{extract_error(response)}")
      when 429
        raise SmartCatalog::RateLimitError.new("Rate limit exceeded: #{extract_error(response)}")
      when 500..599
        raise SmartCatalog::ServiceUnavailableError.new("Gemini service error: #{extract_error(response)}")
      else
        raise SmartCatalog::Error.new("Unexpected response: #{response.status}")
      end
    end

    def extract_error(response)
      response.body.dig('error', 'message') || response.body.to_s[0, 200]
    end

    def format_messages(messages)
      messages.map do |msg|
        role = msg[:role] == 'assistant' ? 'model' : 'user'
        {
          role: role,
          parts: [{ text: msg[:content] }]
        }
      end
    end

    def parse_generate_response(response)
      candidates = response['candidates'] || []
      return nil if candidates.empty?

      content = candidates.first.dig('content', 'parts', 0, 'text')

      {
        content: content,
        finish_reason: candidates.first['finishReason'],
        usage: response['usageMetadata']
      }
    end

    def parse_embedding_response(response)
      response.dig('embedding', 'values') || []
    end
  end
end
