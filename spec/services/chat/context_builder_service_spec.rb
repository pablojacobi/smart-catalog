# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::ContextBuilderService do
  let(:search_service) { instance_double(Search::HybridSearchService) }
  let(:service) { described_class.new(search_service: search_service) }

  describe '#call' do
    let!(:category) { create(:category, name: 'Laptops', slug: 'laptops') }
    let!(:brand) { create(:brand, name: 'Apple', slug: 'apple') }
    let!(:product1) do
      create(:product,
             name: 'MacBook Pro',
             category: category,
             brand: brand,
             price: 1999.99,
             in_stock: true,
             specifications: { 'cpu' => 'M3', 'ram_gb' => 16 })
    end
    let!(:product2) do
      create(:product,
             name: 'MacBook Air',
             category: category,
             brand: brand,
             price: 999.99,
             in_stock: true,
             specifications: { 'cpu' => 'M2', 'ram_gb' => 8 })
    end
    let!(:product3) do
      create(:product,
             name: 'Dell XPS',
             category: category,
             brand: create(:brand, name: 'Dell'),
             price: 1499.99,
             in_stock: false)
    end

    before do
      # Mock hybrid search to return predictable results
      allow(search_service).to receive(:call).and_return([
                                                           { product: product1, score: 0.9, source: 'hybrid' },
                                                           { product: product2, score: 0.8, source: 'hybrid' }
                                                         ])
    end

    context 'with a query and no filters' do
      let(:result) { service.call(query: 'laptop', filters: {}) }

      it 'returns statistics' do
        expect(result[:statistics]).to be_a(Hash)
        expect(result[:statistics]).to include(:total, :by_category, :by_brand, :price_range)
      end

      it 'returns products from search' do
        expect(result[:products]).to eq([product1, product2])
      end

      it 'returns formatted markdown' do
        expect(result[:markdown]).to be_a(String)
        expect(result[:markdown]).to include('Catalog Overview')
        expect(result[:markdown]).to include('Relevant Products')
      end
    end

    context 'with category filter' do
      let(:result) { service.call(query: 'laptop', filters: { category: 'laptops' }) }

      it 'filters statistics by category' do
        expect(result[:statistics][:total]).to be > 0
      end

      it 'includes price range in statistics' do
        expect(result[:statistics][:price_range]).to include(:min, :max)
      end
    end

    context 'with price filters' do
      let(:result) { service.call(query: '', filters: { min_price: 1000, max_price: 2000 }) }

      it 'calculates filtered statistics' do
        # Products with price between 1000-2000
        expect(result[:statistics]).to be_present
      end
    end

    context 'with in_stock filter' do
      let(:result) { service.call(query: '', filters: { in_stock: true }) }

      it 'includes in_stock_count in statistics' do
        expect(result[:statistics][:in_stock_count]).to be >= 0
      end
    end

    context 'with markdown formatting' do
      let(:result) { service.call(query: 'laptop', filters: {}) }

      it 'includes product count in markdown' do
        expect(result[:markdown]).to include('Total matching products')
      end

      it 'includes price range when available' do
        expect(result[:markdown]).to match(/Price range: \$[\d.]+/)
      end

      it 'formats products with name, brand, category, price' do
        expect(result[:markdown]).to include('MacBook Pro')
        expect(result[:markdown]).to include('Apple')
      end

      it 'includes stock indicator' do
        expect(result[:markdown]).to match(/[✓✗]/)
      end

      it 'includes specifications when present' do
        expect(result[:markdown]).to include('cpu: M3')
      end
    end

    context 'with empty results' do
      before do
        allow(search_service).to receive(:call).and_return([])
      end

      it 'returns empty products array' do
        result = service.call(query: 'nonexistent', filters: {})
        expect(result[:products]).to eq([])
      end

      it 'includes "No products found" in markdown' do
        result = service.call(query: 'nonexistent', filters: {})
        expect(result[:markdown]).to include('No products found')
      end
    end
  end
end
