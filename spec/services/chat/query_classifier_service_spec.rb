# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::QueryClassifierService do
  let(:service) { described_class.new }

  describe '#call' do
    it 'classifies listing queries' do
      response_text = {
        query_type: 'listing',
        filters: { category: 'electronics' },
        search_query: 'laptops'
      }.to_json

      stub_gemini_chat(response_text)

      result = service.call('Show me laptops')

      expect(result[:query_type]).to eq('listing')
      expect(result[:filters][:category]).to eq('electronics')
    end

    it 'classifies count queries' do
      response_text = {
        query_type: 'count',
        filters: {},
        search_query: 'products'
      }.to_json

      stub_gemini_chat(response_text)

      result = service.call('How many products do you have?')

      expect(result[:query_type]).to eq('count')
    end

    it 'classifies comparison queries' do
      response_text = {
        query_type: 'comparison',
        filters: {},
        search_query: 'macbook vs dell'
      }.to_json

      stub_gemini_chat(response_text)

      result = service.call('Compare MacBook vs Dell XPS')

      expect(result[:query_type]).to eq('comparison')
    end

    it 'extracts price filters' do
      response_text = {
        query_type: 'listing',
        filters: { min_price: 100, max_price: 500 },
        search_query: 'phones'
      }.to_json

      stub_gemini_chat(response_text)

      result = service.call('Phones between $100 and $500')

      expect(result[:filters][:min_price]).to eq(100)
      expect(result[:filters][:max_price]).to eq(500)
    end

    it 'returns default classification for blank query' do
      result = service.call('')

      expect(result[:query_type]).to eq('listing')
      expect(result[:filters]).to eq({})
    end

    it 'falls back to regex on API error' do
      stub_gemini_error(500, 'Internal server error')

      result = service.call('How many laptops?')

      expect(result[:query_type]).to eq('count')
    end

    it 'includes context in classification' do
      response_text = {
        query_type: 'contextual',
        filters: { max_price: 1000 },
        search_query: ''
      }.to_json

      stub_gemini_chat(response_text)

      previous_products = create_list(:product, 3)
      result = service.call('From those, which are under $1000?', context: { previous_products: previous_products })

      expect(result[:query_type]).to eq('contextual')
    end

    context 'when GPT returns invalid JSON' do
      before do
        stub_gemini_chat('This is not valid JSON at all {broken')
      end

      it 'returns default classification' do
        result = service.call('Some query')

        expect(result[:query_type]).to eq('listing')
        expect(result[:filters]).to eq({})
        expect(result[:search_query]).to eq('')
      end
    end

    context 'when parsing numbers in filters' do
      it 'handles non-numeric price values gracefully' do
        response_text = {
          query_type: 'listing',
          filters: { min_price: 'invalid', max_price: 'not a number' },
          search_query: 'products'
        }.to_json

        stub_gemini_chat(response_text)

        result = service.call('Products with prices')

        # Invalid numbers should be parsed to nil and compacted away
        expect(result[:filters]).not_to have_key(:min_price)
        expect(result[:filters]).not_to have_key(:max_price)
      end
    end

    context 'fallback regex classification' do
      before do
        stub_gemini_error(500, 'Server error')
      end

      it 'classifies comparison queries with regex fallback' do
        result = service.call('Compare iPhone vs Samsung')

        expect(result[:query_type]).to eq('comparison')
      end

      it 'classifies conversational queries with regex fallback' do
        result = service.call('Hello, can you help me?')

        expect(result[:query_type]).to eq('conversational')
      end

      it 'classifies contextual queries with regex fallback' do
        result = service.call('From those items, pick best')

        expect(result[:query_type]).to eq('contextual')
      end

      it 'defaults to listing for unrecognized queries' do
        result = service.call('Show me products with specifications')

        expect(result[:query_type]).to eq('listing')
      end
    end
  end
end
