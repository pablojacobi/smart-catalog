# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gemini::EmbeddingsService do
  describe '.call' do
    let(:text) { 'Sample text for embedding' }

    before do
      allow(Rails.application.config).to receive(:gemini).and_return({
        api_key: 'test-api-key',
        embedding_model: 'text-embedding-004',
        base_url: 'https://generativelanguage.googleapis.com/v1beta',
        timeout: 60
      })

      stub_request(:post, /generativelanguage.googleapis.com.*embedContent/)
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            embedding: {
              values: Array.new(768) { 0.5 }
            }
          }.to_json
        )
    end

    it 'returns embedding vector' do
      result = described_class.call(text)

      expect(result).to be_an(Array)
      expect(result.length).to eq(768)
    end

    it 'returns empty array for blank text' do
      result = described_class.call('')

      expect(result).to eq([])
    end

    it 'sanitizes text before sending' do
      long_text = 'a' * 20_000

      result = described_class.call(long_text)

      expect(result).to be_an(Array)
    end
  end
end
