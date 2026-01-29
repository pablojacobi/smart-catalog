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

    # Stream content generation (yields chunks as they arrive)
    # @param messages [Array<Hash>] Array of message hashes with :role and :content
    # @param model [String] Model to use (defaults to config)
    # @param temperature [Float] Temperature for generation
    # @param max_tokens [Integer] Maximum tokens to generate
    # @yield [String] Yields each text chunk as it arrives
    def stream_content(messages, model: nil, temperature: 0.7, max_tokens: 2048, &block)
      model ||= @config[:model]

      body = {
        contents: format_messages(messages),
        generationConfig: {
          temperature: temperature,
          maxOutputTokens: max_tokens
        }
      }

      stream_post("/models/#{model}:streamGenerateContent", body, &block)
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

    def streaming_connection
      @streaming_connection ||= Faraday.new(url: @base_url) do |f|
        f.request :json
        f.options.timeout = 120 # Longer timeout for streaming
        f.options.open_timeout = 10
        f.adapter Faraday.default_adapter
      end
    end

    def stream_post(endpoint, body, &)
      url = "#{@base_url}#{endpoint}?key=#{@api_key}&alt=sse"
      buffer = +''

      streaming_connection.post(url) do |req|
        req.body = body.to_json
        req.headers['Content-Type'] = 'application/json'
        req.options.on_data = proc do |chunk, _size, _env|
          buffer << chunk
          process_sse_buffer(buffer, &)
        end
      end
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise SmartCatalog::ServiceUnavailableError, "Gemini streaming unavailable: #{e.message}"
    end

    def process_sse_buffer(buffer, &block)
      while (line_end = buffer.index("\n"))
        line = buffer.slice!(0, line_end + 1).strip
        next if line.empty?

        next unless line.start_with?('data: ')

        json_str = line[6..]
        next if json_str == '[DONE]'

        begin
          data = JSON.parse(json_str)
          text = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
          yield text if text && block
        rescue JSON::ParserError
          # Ignore malformed JSON chunks
        end
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
        raise SmartCatalog::ServiceUnavailableError, "Gemini API unavailable: #{e.message}"
      end
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 400
        raise SmartCatalog::ValidationError, "Bad request: #{extract_error(response)}"
      when 401, 403
        raise SmartCatalog::AuthenticationError, "Authentication failed: #{extract_error(response)}"
      when 429
        raise SmartCatalog::RateLimitError, "Rate limit exceeded: #{extract_error(response)}"
      when 500..599
        raise SmartCatalog::ServiceUnavailableError, "Gemini service error: #{extract_error(response)}"
      else
        raise SmartCatalog::Error, "Unexpected response: #{response.status}"
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
