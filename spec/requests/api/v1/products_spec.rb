# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Products' do
  let!(:electronics) { create(:category, name: 'Electronics', slug: 'electronics') }
  let!(:apple) { create(:brand, name: 'Apple', slug: 'apple') }
  let!(:samsung) { create(:brand, name: 'Samsung', slug: 'samsung') }

  let!(:macbook) { create(:product, name: 'MacBook Pro', category: electronics, brand: apple, price: 1999) }
  let!(:iphone) { create(:product, name: 'iPhone 15', category: electronics, brand: apple, price: 999) }
  let!(:galaxy) { create(:product, name: 'Galaxy S24', category: electronics, brand: samsung, price: 899, in_stock: false) }

  describe 'GET /api/v1/products' do
    it 'returns a list of active products' do
      get '/api/v1/products'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']).to be_an(Array)
      expect(json['data'].length).to eq(3)
      expect(json['meta']).to include('current_page', 'per_page', 'total_count')
    end

    it 'filters by category' do
      clothing = create(:category, name: 'Clothing', slug: 'clothing')
      create(:product, name: 'T-Shirt', category: clothing)

      get '/api/v1/products', params: { category: 'electronics' }

      json = response.parsed_body
      names = json['data'].map { |p| p['name'] }

      expect(names).to include('MacBook Pro', 'iPhone 15')
      expect(names).not_to include('T-Shirt')
    end

    it 'filters by brand' do
      get '/api/v1/products', params: { brand: 'apple' }

      json = response.parsed_body
      names = json['data'].map { |p| p['name'] }

      expect(names).to include('MacBook Pro', 'iPhone 15')
      expect(names).not_to include('Galaxy S24')
    end

    it 'filters by price range' do
      get '/api/v1/products', params: { min_price: 900, max_price: 1500 }

      json = response.parsed_body
      names = json['data'].map { |p| p['name'] }

      expect(names).to include('iPhone 15')
      expect(names).not_to include('MacBook Pro', 'Galaxy S24')
    end

    it 'filters by in_stock' do
      get '/api/v1/products', params: { in_stock: true }

      json = response.parsed_body
      names = json['data'].map { |p| p['name'] }

      expect(names).to include('MacBook Pro', 'iPhone 15')
      expect(names).not_to include('Galaxy S24')
    end

    it 'searches by name' do
      get '/api/v1/products', params: { q: 'MacBook' }

      json = response.parsed_body

      expect(json['data'].length).to eq(1)
      expect(json['data'].first['name']).to eq('MacBook Pro')
    end

    it 'sorts by price descending' do
      get '/api/v1/products', params: { sort: 'price_desc' }

      json = response.parsed_body
      prices = json['data'].map { |p| p['price'].to_f }

      expect(prices).to eq(prices.sort.reverse)
    end

    it 'paginates results' do
      get '/api/v1/products', params: { page: 1, per_page: 2 }

      json = response.parsed_body

      expect(json['data'].length).to eq(2)
      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['per_page']).to eq(2)
      expect(json['meta']['total_count']).to eq(3)
      expect(json['meta']['has_next_page']).to be true
    end

    it 'combines multiple filters' do
      get '/api/v1/products', params: {
        category: 'electronics',
        brand: 'apple',
        max_price: 1500,
        in_stock: true
      }

      json = response.parsed_body

      expect(json['data'].length).to eq(1)
      expect(json['data'].first['name']).to eq('iPhone 15')
    end
  end

  describe 'GET /api/v1/products/:id' do
    it 'returns product details' do
      get "/api/v1/products/#{macbook.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']['id']).to eq(macbook.id)
      expect(json['data']['name']).to eq('MacBook Pro')
      expect(json['data']['specifications']).to be_present
      expect(json['data']['category']['name']).to eq('Electronics')
      expect(json['data']['brand']['name']).to eq('Apple')
    end

    it 'returns 404 for non-existent product' do
      get '/api/v1/products/non-existent-id'

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body

      expect(json['error']['code']).to eq('not_found')
    end
  end
end
