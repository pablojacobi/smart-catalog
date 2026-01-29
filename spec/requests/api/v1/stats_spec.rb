# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Stats' do
  describe 'GET /api/v1/stats' do
    let!(:electronics) { create(:category, name: 'Electronics') }
    let!(:clothing) { create(:category, name: 'Clothing') }
    let!(:apple) { create(:brand, name: 'Apple') }
    let!(:samsung) { create(:brand, name: 'Samsung') }

    let!(:products) do
      [
        create(:product, category: electronics, brand: apple, status: 'active', in_stock: true, price: 999),
        create(:product, :with_embedding, category: electronics, brand: samsung, status: 'active', in_stock: false, price: 899),
        create(:product, category: clothing, brand: nil, status: 'inactive', in_stock: true, price: nil)
      ]
    end

    it 'returns stats overview' do
      get '/api/v1/stats'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['stats']).to be_present
      expect(json['generated_at']).to be_present
    end

    it 'returns product statistics' do
      get '/api/v1/stats'

      json = response.parsed_body
      product_stats = json['stats']['products']

      expect(product_stats['total']).to eq(3)
      expect(product_stats['active']).to eq(2)
      expect(product_stats['in_stock']).to eq(2)
      expect(product_stats['with_price']).to eq(2)
      expect(product_stats['with_embedding']).to eq(1)
    end

    it 'returns products grouped by category' do
      get '/api/v1/stats'

      json = response.parsed_body
      by_category = json['stats']['products']['by_category']

      expect(by_category['Electronics']).to eq(2)
      expect(by_category['Clothing']).to eq(1)
    end

    it 'returns products grouped by brand' do
      get '/api/v1/stats'

      json = response.parsed_body
      by_brand = json['stats']['products']['by_brand']

      expect(by_brand['Apple']).to eq(1)
      expect(by_brand['Samsung']).to eq(1)
    end

    it 'returns category and brand counts' do
      get '/api/v1/stats'

      json = response.parsed_body

      expect(json['stats']['categories']).to eq(2)
      expect(json['stats']['brands']).to eq(2)
    end
  end
end
