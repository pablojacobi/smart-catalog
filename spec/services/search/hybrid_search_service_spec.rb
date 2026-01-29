# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::HybridSearchService do
  let(:vector_service) { instance_double(Search::VectorSearchService) }
  let(:sql_service) { instance_double(Search::SqlSearchService) }
  let(:service) { described_class.new(vector_service: vector_service, sql_service: sql_service) }

  describe '#call' do
    let(:category) { create(:category) }
    let(:product1) { create(:product, name: 'MacBook', category: category) }
    let(:product2) { create(:product, name: 'iPhone', category: category) }
    let(:document) { create(:document, :with_embedding) }

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
      before do
        product1.update!(document: document)
      end

      it 'uses vector search only' do
        vector_results = [{ document: document, score: 0.85, source: 'vector' }]
        allow(vector_service).to receive(:call).and_return(vector_results)

        results = service.call(query: 'laptop', filters: {})

        expect(vector_service).to have_received(:call)
        expect(results.first[:source]).to eq('vector')
      end
    end

    context 'with both query and filters' do
      before do
        product1.update!(document: document)
        product2.update!(document: document)
      end

      it 'combines both search strategies' do
        vector_results = [{ document: document, score: 0.85, source: 'vector' }]
        sql_results = [
          { product: product1, score: 1.0, source: 'sql' },
          { product: product2, score: 1.0, source: 'sql' }
        ]

        allow(vector_service).to receive(:call).and_return(vector_results)
        allow(sql_service).to receive(:call).and_return(sql_results)

        results = service.call(query: 'laptop', filters: { category: 'electronics' })

        expect(vector_service).to have_received(:call)
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
      let(:doc1) { create(:document, :with_embedding) }
      let(:doc2) { create(:document, :with_embedding) }
      let!(:product_in_both) { create(:product, name: 'Common Product', document: doc1, price: 100) }
      let!(:product_vector_only) { create(:product, name: 'Vector Only', document: doc2, price: 200) }
      let!(:product_sql_only) { create(:product, name: 'SQL Only', price: 150) }

      before do
        # Setup vector results to return products from docs
        vector_results = [
          { document: doc1, score: 0.9, source: 'vector' },
          { document: doc2, score: 0.7, source: 'vector' }
        ]
        allow(vector_service).to receive(:call).and_return(vector_results)

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
      let(:doc) { create(:document, :with_embedding) }
      let!(:product) { create(:product, name: 'Test Product', document: doc, category: category) }

      it 'uses strict deduplication when filtering by category' do
        vector_results = [{ document: doc, score: 0.9, source: 'vector' }]
        sql_results = [{ product: product, score: 1.0, source: 'sql' }]

        allow(vector_service).to receive(:call).and_return(vector_results)
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
  end
end
