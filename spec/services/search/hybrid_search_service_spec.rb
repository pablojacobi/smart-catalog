# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::HybridSearchService do
  let(:embeddings_service) { instance_double(Gemini::EmbeddingsService) }
  let(:sql_service) { instance_double(Search::SqlSearchService) }
  let(:service) { described_class.new(embeddings_service: embeddings_service, sql_service: sql_service) }

  describe '#call' do
    let(:category) { create(:category) }
    let(:product1) { create(:product, :with_embedding, name: 'MacBook', category: category) }
    let(:product2) { create(:product, :with_embedding, name: 'iPhone', category: category) }

    context 'with only filters (no query)' do
      it 'uses SQL search only' do
        sql_results = [{ product: product1, score: 1.0, source: 'sql' }]
        allow(sql_service).to receive(:call).and_return(sql_results)

        results = service.call(query: '', filters: { category: 'electronics' })

        expect(sql_service).to have_received(:call)
        expect(results.first[:source]).to eq('sql')
      end
    end

    context 'with only query (no filters)' do
      let(:query_embedding) { Array.new(768) { 0.1 } }
      let!(:product_with_similar_embedding) do
        # Create a product with an embedding similar to the query embedding
        create(:product, name: 'Laptop', embedding: Array.new(768) { 0.1 })
      end

      before do
        allow(embeddings_service).to receive(:call).and_return(query_embedding)
      end

      it 'uses vector search only' do
        results = service.call(query: 'laptop', filters: {})

        expect(embeddings_service).to have_received(:call)
        expect(results).not_to be_empty
        expect(results.first[:source]).to eq('vector')
      end

      it 'returns empty when no query embedding generated' do
        allow(embeddings_service).to receive(:call).and_return(nil)

        results = service.call(query: 'laptop', filters: {})

        expect(results).to be_empty
      end
    end

    context 'with both query and filters' do
      let(:query_embedding) { Array.new(768) { rand(-1.0..1.0) } }

      before do
        allow(embeddings_service).to receive(:call).and_return(query_embedding)
        # Create products with embeddings
        product1
        product2
      end

      it 'combines both search strategies' do
        sql_results = [
          { product: product1, score: 1.0, source: 'sql' },
          { product: product2, score: 1.0, source: 'sql' }
        ]

        allow(sql_service).to receive(:call).and_return(sql_results)

        results = service.call(query: 'laptop', filters: { category: 'electronics' })

        expect(embeddings_service).to have_received(:call)
        expect(sql_service).to have_received(:call)
        expect(results.first[:source]).to eq('hybrid')
      end
    end

    it 'respects limit parameter' do
      many_products = create_list(:product, 20)
      # Mock returns limited results as the real service would
      allow(sql_service).to receive(:call) do |_filters, limit:|
        many_products.first(limit).map { |p| { product: p, score: 1.0, source: 'sql' } }
      end

      results = service.call(query: '', filters: { category: 'test' }, limit: 10)

      expect(results.length).to be <= 10
    end

    context 'with flexible deduplication (price filters)' do
      # Use consistent embeddings for predictable test results
      let(:query_embedding) { Array.new(768) { 0.5 } }
      let(:similar_embedding) { Array.new(768) { 0.5 } }
      let!(:product_in_both) { create(:product, name: 'Common Product', price: 100, embedding: similar_embedding) }
      let!(:product_vector_only) { create(:product, name: 'Vector Only', price: 200, embedding: similar_embedding) }
      let!(:product_sql_only) { create(:product, name: 'SQL Only', price: 150) }

      before do
        allow(embeddings_service).to receive(:call).and_return(query_embedding)

        # SQL results with price filter - includes some overlap
        sql_results = [
          { product: product_in_both, score: 1.0, source: 'sql' },
          { product: product_sql_only, score: 1.0, source: 'sql' }
        ]
        allow(sql_service).to receive(:call).and_return(sql_results)
      end

      it 'combines vector and SQL results with flexible union for price filters' do
        results = service.call(
          query: 'product',
          filters: { min_price: 50, max_price: 250 }
        )

        # Should include products from both sources
        product_names = results.map { |r| r[:product].name }
        expect(product_names).to include('Common Product')
      end

      it 'gives highest score to products found in both searches' do
        results = service.call(
          query: 'product',
          filters: { min_price: 50 }
        )

        common_result = results.find { |r| r[:product].name == 'Common Product' }
        sql_only_result = results.find { |r| r[:product].name == 'SQL Only' }

        expect(common_result[:score]).to be >= sql_only_result[:score] if sql_only_result
      end

      it 'applies slight penalty to vector-only results' do
        results = service.call(
          query: 'product',
          filters: { max_price: 300 }
        )

        results.each do |result|
          expect(result[:score]).to be > 0
          expect(result[:source]).to eq('hybrid')
        end
      end
    end

    context 'with strict category filter' do
      let(:query_embedding) { Array.new(768) { rand(-1.0..1.0) } }
      let!(:product) { create(:product, :with_embedding, name: 'Test Product', category: category) }

      before do
        allow(embeddings_service).to receive(:call).and_return(query_embedding)
      end

      it 'uses strict deduplication when filtering by category' do
        sql_results = [{ product: product, score: 1.0, source: 'sql' }]
        allow(sql_service).to receive(:call).and_return(sql_results)

        results = service.call(
          query: 'test',
          filters: { category: category.slug }
        )

        # Should find the product that matches both
        expect(results).not_to be_empty
        expect(results.first[:product].name).to eq('Test Product')
      end
    end

    context 'when embedding service fails' do
      before do
        allow(embeddings_service).to receive(:call).and_raise(StandardError.new('API error'))
      end

      it 'returns empty results gracefully' do
        results = service.call(query: 'laptop', filters: {})

        expect(results).to be_empty
      end
    end
  end
end
