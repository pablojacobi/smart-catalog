# frozen_string_literal: true

# Helper methods for stubbing Gemini API calls in tests
module GeminiHelpers
  def stub_gemini_chat(response_text = 'Test response')
    stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          candidates: [
            {
              content: {
                parts: [{ text: response_text }],
                role: 'model'
              },
              finishReason: 'STOP'
            }
          ],
          usageMetadata: {
            promptTokenCount: 100,
            candidatesTokenCount: 50
          }
        }.to_json
      )
  end

  def stub_gemini_embedding(dimensions = 768)
    stub_request(:post, /generativelanguage.googleapis.com.*embedContent/)
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          embedding: {
            values: Array.new(dimensions) { rand(-1.0..1.0) }
          }
        }.to_json
      )
  end

  def stub_gemini_error(status, message)
    stub_request(:post, /generativelanguage.googleapis.com/)
      .to_return(
        status: status,
        headers: { 'Content-Type' => 'application/json' },
        body: { error: { message: message } }.to_json
      )
  end
end

RSpec.configure do |config|
  config.include GeminiHelpers
end
