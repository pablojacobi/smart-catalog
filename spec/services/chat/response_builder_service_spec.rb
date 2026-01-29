# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::ResponseBuilderService do
  let(:mock_client) { instance_double(Gemini::ClientService) }
  let(:service) { described_class.new(client: mock_client) }

  let!(:category) { create(:category, name: 'Electronics') }
  let!(:brand) { create(:brand, name: 'Apple') }
  let!(:products) do
    [
      create(:product, name: 'MacBook Pro', brand: brand, category: category, price: 1999,
                       specifications: { 'RAM' => '16GB', 'Storage' => '512GB' }),
      create(:product, name: 'iPhone 15', brand: brand, category: category, price: 999,
                       specifications: { 'Storage' => '128GB' }),
      create(:product, name: 'iPad Air', brand: brand, category: category, price: 599, in_stock: false)
    ]
  end

  describe '#call' do
    context 'with listing query type' do
      it 'builds listing response with products' do
        result = service.call(query_type: 'listing', products: products, query: 'Show me Apple products')

        expect(result[:content]).to include('Products Found')
        expect(result[:content]).to include('MacBook Pro')
        expect(result[:content]).to include('iPhone 15')
        expect(result[:product_ids]).to match_array(products.map(&:id))
        expect(result[:response_type]).to eq('listing')
      end

      it 'returns no products message when empty' do
        result = service.call(query_type: 'listing', products: [], query: 'Show me products')

        expect(result[:content]).to include('No products found')
        expect(result[:product_ids]).to be_empty
        expect(result[:response_type]).to eq('listing')
      end

      it 'truncates large result sets' do
        many_products = create_list(:product, 25, brand: brand, category: category)

        result = service.call(query_type: 'listing', products: many_products, query: 'Show all')

        expect(result[:content]).to include('and 5 more products')
      end

      it 'includes product details in listing' do
        result = service.call(query_type: 'listing', products: products, query: 'List products')

        expect(result[:content]).to include('Brand')
        expect(result[:content]).to include('Category')
        expect(result[:content]).to include('Price')
        expect(result[:content]).to include('In Stock')
      end

      it 'includes specifications when present' do
        result = service.call(query_type: 'listing', products: [products.first], query: 'Show MacBook')

        expect(result[:content]).to include('Specs')
        expect(result[:content]).to include('RAM')
      end
    end

    context 'with count query type' do
      it 'builds count response with total' do
        result = service.call(
          query_type: 'count',
          products: products,
          query: 'How many products?',
          context: { counts: { total: 3 } }
        )

        expect(result[:content]).to include('Product Count')
        expect(result[:content]).to include('3 products')
        expect(result[:product_ids]).to be_empty
        expect(result[:response_type]).to eq('count')
      end

      it 'includes category breakdown when provided' do
        result = service.call(
          query_type: 'count',
          products: products,
          query: 'How many by category?',
          context: {
            counts: {
              total: 10,
              by_category: { 'Electronics' => 5, 'Clothing' => 3, 'Home' => 2 }
            }
          }
        )

        expect(result[:content]).to include('By Category')
        expect(result[:content]).to include('Electronics: 5')
        expect(result[:content]).to include('Clothing: 3')
      end

      it 'includes brand breakdown when provided and not too many' do
        result = service.call(
          query_type: 'count',
          products: products,
          query: 'How many by brand?',
          context: {
            counts: {
              total: 10,
              by_brand: { 'Apple' => 5, 'Samsung' => 3 }
            }
          }
        )

        expect(result[:content]).to include('By Brand')
        expect(result[:content]).to include('Apple: 5')
      end

      it 'uses products length as default count' do
        result = service.call(
          query_type: 'count',
          products: products,
          query: 'Count products',
          context: {}
        )

        expect(result[:content]).to include('3 products')
      end
    end

    context 'with comparison query type' do
      before do
        allow(mock_client).to receive(:generate_content).and_return(
          { content: 'Here is a comparison of the products...' }
        )
      end

      it 'builds comparison response using LLM' do
        result = service.call(query_type: 'comparison', products: products, query: 'Compare MacBook and iPhone')

        expect(result[:content]).to include('comparison')
        expect(result[:product_ids]).to match_array(products.map(&:id))
        expect(result[:response_type]).to eq('comparison')
        expect(mock_client).to have_received(:generate_content)
      end

      it 'returns no products message when empty' do
        result = service.call(query_type: 'comparison', products: [], query: 'Compare products')

        expect(result[:content]).to include("couldn't find products to compare")
        expect(result[:response_type]).to eq('comparison')
      end

      it 'limits products to 5 for comparison' do
        many_products = create_list(:product, 10, brand: brand, category: category)

        service.call(query_type: 'comparison', products: many_products, query: 'Compare all')

        expect(mock_client).to have_received(:generate_content) do |messages, **_opts|
          # Should only include 5 products in the message
          product_content = messages.last[:content]
          expect(product_content.scan('Name:').count).to eq(5)
        end
      end
    end

    context 'with conversational query type' do
      before do
        allow(mock_client).to receive(:generate_content).and_return(
          { content: 'Hello! I can help you find products.' }
        )
      end

      it 'builds conversational response using LLM' do
        result = service.call(query_type: 'conversational', products: [], query: 'Hello!')

        expect(result[:content]).to include('help you find products')
        expect(result[:product_ids]).to be_empty
        expect(result[:response_type]).to eq('conversational')
        expect(mock_client).to have_received(:generate_content)
      end

      it 'provides default response if LLM fails' do
        allow(mock_client).to receive(:generate_content).and_return({ content: nil })

        result = service.call(query_type: 'conversational', products: [], query: 'Hi')

        expect(result[:content]).to include('help you find products')
      end
    end

    context 'with contextual query type' do
      before do
        allow(mock_client).to receive(:generate_content).and_return(
          { content: 'Based on your previous results...' }
        )
      end

      it 'builds contextual response using LLM' do
        result = service.call(
          query_type: 'contextual',
          products: products,
          query: 'Which is cheapest?',
          context: { previous_product_ids: products.map(&:id) }
        )

        expect(result[:content]).to include('previous results')
        expect(result[:product_ids]).to match_array(products.map(&:id))
        expect(result[:response_type]).to eq('contextual')
      end

      it 'returns no products message when empty' do
        result = service.call(
          query_type: 'contextual',
          products: [],
          query: 'Which is best?',
          context: {}
        )

        expect(result[:content]).to include("don't have previous results")
        expect(result[:response_type]).to eq('contextual')
      end

      it 'falls back to product list if LLM fails' do
        allow(mock_client).to receive(:generate_content).and_return({ content: nil })

        result = service.call(
          query_type: 'contextual',
          products: products,
          query: 'Which one?',
          context: {}
        )

        expect(result[:content]).to include('MacBook Pro')
      end
    end

    context 'with unknown query type' do
      it 'defaults to listing response' do
        result = service.call(query_type: 'unknown', products: products, query: 'Something')

        expect(result[:response_type]).to eq('listing')
        expect(result[:content]).to include('Products Found')
      end
    end
  end

  describe 'product formatting' do
    it 'handles products without brand' do
      product = create(:product, name: 'Generic Item', brand: nil, category: category, price: 100)

      result = service.call(query_type: 'listing', products: [product], query: 'Show item')

      expect(result[:content]).to include('N/A')
    end

    it 'handles products without category' do
      product = create(:product, name: 'Uncategorized', brand: brand, category: nil, price: 100)

      result = service.call(query_type: 'listing', products: [product], query: 'Show item')

      expect(result[:content]).to include('N/A')
    end

    it 'handles products without price' do
      product = create(:product, name: 'Contact Us', brand: brand, category: category, price: nil)

      result = service.call(query_type: 'listing', products: [product], query: 'Show item')

      expect(result[:content]).to include('Contact for price')
    end

    it 'shows out of stock status' do
      product = create(:product, name: 'Sold Out', brand: brand, category: category, price: 100, in_stock: false)

      result = service.call(query_type: 'listing', products: [product], query: 'Show item')

      expect(result[:content]).to include('In Stock:** No')
    end
  end
end
