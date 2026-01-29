# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gemini::ClientService do
  let(:service) { described_class.new }

  before do
    allow(Rails.application.config).to receive(:gemini).and_return({
                                                                     api_key: 'test-api-key',
                                                                     model: 'gemini-1.5-flash',
                                                                     embedding_model: 'text-embedding-004',
                                                                     base_url: 'https://generativelanguage.googleapis.com/v1beta',
                                                                     timeout: 60
                                                                   })
  end

  describe '#generate_content' do
    let(:messages) { [{ role: 'user', content: 'Hello' }] }

    context 'with successful response' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: {
              candidates: [
                {
                  content: {
                    parts: [{ text: 'Hello! How can I help you?' }],
                    role: 'model'
                  },
                  finishReason: 'STOP'
                }
              ],
              usageMetadata: {
                promptTokenCount: 10,
                candidatesTokenCount: 20
              }
            }.to_json
          )
      end

      it 'returns parsed response' do
        result = service.generate_content(messages)

        expect(result[:content]).to eq('Hello! How can I help you?')
        expect(result[:finish_reason]).to eq('STOP')
      end
    end

    context 'with rate limit error' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 429,
            headers: { 'Content-Type' => 'application/json' },
            body: { error: { message: 'Rate limit exceeded' } }.to_json
          )
      end

      it 'raises RateLimitError' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::RateLimitError)
      end
    end

    context 'with authentication error' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 401,
            headers: { 'Content-Type' => 'application/json' },
            body: { error: { message: 'Invalid API key' } }.to_json
          )
      end

      it 'raises AuthenticationError' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::AuthenticationError)
      end
    end

    context 'with validation error (400)' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 400,
            headers: { 'Content-Type' => 'application/json' },
            body: { error: { message: 'Invalid request format' } }.to_json
          )
      end

      it 'raises ValidationError' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::ValidationError, /Bad request/)
      end
    end

    context 'with server error (500)' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 500,
            headers: { 'Content-Type' => 'application/json' },
            body: { error: { message: 'Internal server error' } }.to_json
          )
      end

      it 'raises ServiceUnavailableError' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::ServiceUnavailableError, /Gemini service error/)
      end
    end

    context 'with unexpected status code' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 418,
            headers: { 'Content-Type' => 'application/json' },
            body: { error: { message: 'I am a teapot' } }.to_json
          )
      end

      it 'raises generic Error' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::Error, /Unexpected response: 418/)
      end
    end

    context 'with network timeout' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_timeout
      end

      it 'retries and raises ServiceUnavailableError after max retries' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::ServiceUnavailableError, /Gemini API unavailable/)
      end
    end

    context 'with connection failure' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'retries and raises ServiceUnavailableError after max retries' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::ServiceUnavailableError, /Gemini API unavailable/)
      end
    end
  end

  describe '#embed' do
    let(:text) { 'This is a test document' }

    context 'with successful response' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*embedContent/)
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: {
              embedding: {
                values: Array.new(768) { rand }
              }
            }.to_json
          )
      end

      it 'returns embedding vector' do
        result = service.embed(text)

        expect(result).to be_an(Array)
        expect(result.length).to eq(768)
      end
    end

    context 'with missing embedding' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*embedContent/)
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: {}.to_json
          )
      end

      it 'returns empty array' do
        expect(service.embed(text)).to eq([])
      end
    end
  end

  describe '#stream_content' do
    let(:messages) { [{ role: 'user', content: 'Hello' }] }

    context 'with successful streaming response' do
      let(:mock_http) { instance_double(Net::HTTP) }
      let(:mock_response) { instance_double(Net::HTTPResponse) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:request).and_yield(mock_response)

        # Simulate SSE chunks
        chunks = [
          "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hello\"}]}}]}\n\n",
          "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" World\"}]}}]}\n\n"
        ]
        allow(mock_response).to receive(:read_body) do |&block|
          chunks.each { |chunk| block.call(chunk) }
        end
      end

      it 'yields text chunks' do
        chunks = []
        service.stream_content(messages) { |chunk| chunks << chunk }
        expect(chunks).to eq(['Hello', ' World'])
      end
    end

    context 'with connection error during streaming' do
      before do
        allow(Net::HTTP).to receive(:new).and_raise(Errno::ECONNRESET)
      end

      it 'raises ServiceUnavailableError' do
        expect { service.stream_content(messages) { |chunk| chunk } }
          .to raise_error(SmartCatalog::ServiceUnavailableError, /streaming unavailable/)
      end
    end

    context 'with timeout during streaming' do
      before do
        allow(Net::HTTP).to receive(:new).and_raise(Faraday::TimeoutError)
      end

      it 'raises ServiceUnavailableError' do
        expect { service.stream_content(messages) { |chunk| chunk } }
          .to raise_error(SmartCatalog::ServiceUnavailableError, /streaming unavailable/)
      end
    end

    context 'with malformed JSON in SSE' do
      let(:mock_http) { instance_double(Net::HTTP) }
      let(:mock_response) { instance_double(Net::HTTPResponse) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:request).and_yield(mock_response)

        allow(mock_response).to receive(:read_body).and_yield("data: {invalid json}\n\n").and_yield("data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Valid\"}]}}]}\n\n")
      end

      it 'ignores malformed JSON and continues' do
        chunks = []
        service.stream_content(messages) { |chunk| chunks << chunk }
        expect(chunks).to eq(['Valid'])
      end
    end

    context 'with [DONE] marker' do
      let(:mock_http) { instance_double(Net::HTTP) }
      let(:mock_response) { instance_double(Net::HTTPResponse) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:request).and_yield(mock_response)

        allow(mock_response).to receive(:read_body).and_yield("data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hello\"}]}}]}\n\n").and_yield("data: [DONE]\n\n")
      end

      it 'stops processing at [DONE]' do
        chunks = []
        service.stream_content(messages) { |chunk| chunks << chunk }
        expect(chunks).to eq(['Hello'])
      end
    end
  end

  describe '#generate_content edge cases' do
    let(:messages) { [{ role: 'user', content: 'Hello' }, { role: 'assistant', content: 'Hi' }] }

    context 'with empty candidates' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: { candidates: [] }.to_json
          )
      end

      it 'returns nil content' do
        result = service.generate_content(messages)
        expect(result[:content]).to be_nil
      end
    end

    context 'with error response as string body' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(
            status: 400,
            headers: { 'Content-Type' => 'text/plain' },
            body: 'Plain text error message'
          )
      end

      it 'handles string error body' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::ValidationError)
      end
    end

    context 'with blank error response' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
          .to_return(status: 403, body: '')
      end

      it 'handles empty body' do
        expect { service.generate_content(messages) }
          .to raise_error(SmartCatalog::AuthenticationError)
      end
    end
  end
end
