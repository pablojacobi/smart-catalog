# frozen_string_literal: true

module Ollama
  # HTTP client for Ollama local API
  # Handles chat completions and embeddings locally
  class ClientService
    include CallableService

    RETRY_ERRORS = [Faraday::TimeoutError, Faraday::ConnectionFailed].freeze
    MAX_RETRIES = 3

    def initialize
      @config = Rails.application.config.ollama
      @base_url = @config[:base_url]
    end

    # Generate content (chat completion)
    def generate_content(messages, model: nil, temperature: 0.7, max_tokens: 2048)
      model ||= @config[:model]

      body = {
        model: model,
        messages: format_messages(messages),
        options: {
          temperature: temperature,
          num_predict: max_tokens
        },
        stream: false
      }

      response = post('/api/chat', body)
      parse_generate_response(response)
    end

    # Stream content generation (yields chunks as they arrive)
    def stream_content(messages, model: nil, temperature: 0.7, max_tokens: 2048, &)
      model ||= @config[:model]

      body = {
        model: model,
        messages: format_messages(messages),
        options: {
          temperature: temperature,
          num_predict: max_tokens
        },
        stream: true
      }

      stream_chat(body, &)
    end

    # Generate embeddings
    def embed(text, model: nil)
      model ||= @config[:embedding_model]

      body = {
        model: model,
        input: text.to_s[0, 10_000]
      }

      response = post('/api/embed', body)
      parse_embedding_response(response)
    end

    private

    def connection
      @connection ||= Faraday.new do |f|
        f.request :json
        f.response :json
        f.options.timeout = @config[:timeout]
        f.options.open_timeout = 30
        f.adapter Faraday.default_adapter
      end
    end

    def post(endpoint, body)
      retries = 0
      full_url = "#{@base_url}#{endpoint}"

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
        raise SmartCatalog::ServiceUnavailableError, "Ollama API unavailable: #{e.message}"
      end
    end

    def stream_chat(body, &)
      url = "#{@base_url}/api/chat"

      http_stream_request(url, body) do |chunk|
        process_stream_chunk(chunk, &)
      end
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Errno::ECONNRESET => e
      raise SmartCatalog::ServiceUnavailableError, "Ollama streaming unavailable: #{e.message}"
    end

    def http_stream_request(url, body, &)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 300
      http.open_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json

      http.request(request) do |response|
        response.read_body(&)
      end
    end

    def process_stream_chunk(chunk)
      chunk.each_line do |line|
        next if line.strip.empty?

        begin
          data = JSON.parse(line)
          content = data.dig('message', 'content')
          yield content if content.present?
        rescue JSON::ParserError
          # Ignore malformed JSON
        end
      end
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 400
        raise SmartCatalog::ValidationError, "Bad request: #{extract_error(response)}"
      when 404
        raise SmartCatalog::ServiceUnavailableError, "Model not found. Run: ollama pull #{@config[:model]}"
      when 500..599
        raise SmartCatalog::ServiceUnavailableError, "Ollama service error: #{extract_error(response)}"
      else
        raise SmartCatalog::Error, "Unexpected response: #{response.status} - #{extract_error(response)}"
      end
    end

    def extract_error(response)
      return '' if response.body.blank?

      if response.body.is_a?(Hash)
        response.body['error'] || response.body.to_s[0, 200]
      else
        response.body.to_s[0, 200]
      end
    end

    def format_messages(messages)
      messages.map do |msg|
        {
          role: msg[:role],
          content: msg[:content]
        }
      end
    end

    def parse_generate_response(response)
      content = response.dig('message', 'content')

      {
        content: content,
        finish_reason: response['done'] ? 'stop' : nil,
        usage: {
          prompt_tokens: response['prompt_eval_count'],
          completion_tokens: response['eval_count']
        }
      }
    end

    def parse_embedding_response(response)
      # Ollama returns embeddings as array of arrays (for batch support)
      embeddings = response['embeddings'] || response['embedding']
      return [] if embeddings.blank?

      # If single embedding, return it directly
      embeddings.is_a?(Array) && embeddings.first.is_a?(Array) ? embeddings.first : embeddings
    end
  end
end
