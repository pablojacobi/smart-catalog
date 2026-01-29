# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gemini::ChatService do
  describe '.call' do
    let(:messages) { [{ role: 'user', content: 'Tell me about laptops' }] }

    before do
      allow(Rails.application.config).to receive(:gemini).and_return({
                                                                       api_key: 'test-api-key',
                                                                       model: 'gemini-1.5-flash',
                                                                       base_url: 'https://generativelanguage.googleapis.com/v1beta',
                                                                       timeout: 60
                                                                     })

      stub_request(:post, /generativelanguage.googleapis.com.*generateContent/)
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            candidates: [
              {
                content: {
                  parts: [{ text: 'Here are some laptop recommendations...' }],
                  role: 'model'
                }
              }
            ]
          }.to_json
        )
    end

    it 'returns response content' do
      result = described_class.call(messages: messages)

      expect(result).to eq('Here are some laptop recommendations...')
    end

    it 'includes system prompt when provided' do
      result = described_class.call(
        messages: messages,
        system_prompt: 'You are a helpful assistant'
      )

      expect(result).to be_present
    end
  end
end
