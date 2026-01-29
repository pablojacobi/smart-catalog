# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CallableService do
  # Create test service classes
  let(:simple_service_class) do
    Class.new do
      include CallableService

      def initialize(value: 0)
        @value = value
      end

      def call
        @value * 2
      end
    end
  end

  let(:complex_service_class) do
    Class.new do
      include CallableService

      def initialize(a:, b:, c: 0)
        @a = a
        @b = b
        @c = c
      end

      def call
        @a + @b + @c
      end
    end
  end

  describe '.call' do
    it 'creates instance and calls the call method' do
      result = simple_service_class.call(value: 5)
      expect(result).to eq(10)
    end

    it 'passes keyword arguments to initialize' do
      result = complex_service_class.call(a: 1, b: 2, c: 3)
      expect(result).to eq(6)
    end

    it 'uses default values for optional arguments' do
      result = simple_service_class.call
      expect(result).to eq(0)
    end

    it 'passes only required arguments' do
      result = complex_service_class.call(a: 10, b: 20)
      expect(result).to eq(30) # c defaults to 0
    end
  end

  describe 'integration with real services' do
    it 'works with Gemini::EmbeddingsService' do
      stub_gemini_embedding(768)

      result = Gemini::EmbeddingsService.call(text: 'test')
      expect(result).to be_an(Array)
      expect(result.length).to eq(768)
    end
  end
end
