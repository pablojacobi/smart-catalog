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
    def stream_content(messages, model: nil, temperature: 0.7, max_tokens: 2048, &)
      model ||= @config[:model]

      body = {
        contents: format_messages(messages),
        generationConfig: {
          temperature: temperature,
          maxOutputTokens: max_tokens
        }
      }

      stream_generate("/models/#{model}:streamGenerateContent", body, &)
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
      @connection ||= Faraday.new do |f|
        f.request :json
        f.response :json
        f.options.timeout = @config[:timeout]
        f.options.open_timeout = 10
        f.adapter Faraday.default_adapter
      end
    end

    def post(endpoint, body)
      retries = 0
      full_url = "#{@base_url}#{endpoint}?key=#{@api_key}"

      begin
        response = connection.post(full_url) do |req|
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

    def stream_generate(endpoint, body, &)
      url = "#{@base_url}#{endpoint}?key=#{@api_key}&alt=sse"
      buffer = +''

      http_stream_request(url, body) do |chunk|
        buffer << chunk
        process_sse_buffer(buffer, &)
      end
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Errno::ECONNRESET => e
      raise SmartCatalog::ServiceUnavailableError, "Gemini streaming unavailable: #{e.message}"
    end

    def http_stream_request(url, body, &)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 120
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json

      http.request(request) do |response|
        response.read_body(&)
      end
    end

    def process_sse_buffer(buffer)
      # Handle both \r\n and \n line endings
      while (line_end = buffer.index(/\r?\n/))
        match = buffer.match(/\r?\n/)
        line = buffer.slice!(0, line_end + match[0].length).strip
        next if line.empty?
        next unless line.start_with?('data: ')

        json_str = line[6..]
        next if json_str == '[DONE]'

        begin
          data = JSON.parse(json_str)
          text = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
          yield text if text
        rescue JSON::ParserError
          # Ignore malformed JSON chunks
        end
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
        raise SmartCatalog::Error, "Unexpected response: #{response.status} - #{extract_error(response)}"
      end
    end

    def extract_error(response)
      return '' if response.body.blank?

      if response.body.is_a?(Hash)
        response.body.dig('error', 'message') || response.body.to_s[0, 200]
      else
        response.body.to_s[0, 200]
      end
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
      return { content: nil, finish_reason: nil, usage: nil } if candidates.empty?

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
