# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmartCatalog do
  describe SmartCatalog::Error do
    it 'is a StandardError' do
      expect(described_class.new).to be_a(StandardError)
    end

    it 'accepts code and details' do
      error = described_class.new('Something went wrong', code: 'test_error', details: { foo: 'bar' })

      expect(error.message).to eq('Something went wrong')
      expect(error.code).to eq('test_error')
      expect(error.details).to eq({ foo: 'bar' })
    end
  end

  describe SmartCatalog::NotFoundError do
    it 'has default message and code' do
      error = described_class.new

      expect(error.message).to eq('Resource not found')
      expect(error.code).to eq('not_found')
    end
  end

  describe SmartCatalog::ValidationError do
    it 'has default message and code' do
      error = described_class.new

      expect(error.message).to eq('Validation failed')
      expect(error.code).to eq('validation_error')
    end
  end

  describe SmartCatalog::GeminiError do
    it 'has default message and code' do
      error = described_class.new

      expect(error.message).to eq('Gemini API error')
      expect(error.code).to eq('gemini_error')
    end
  end

  describe SmartCatalog::RateLimitError do
    it 'has default message and code' do
      error = described_class.new

      expect(error.message).to eq('Rate limit exceeded')
      expect(error.code).to eq('rate_limit_exceeded')
    end
  end
end
