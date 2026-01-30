# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Categories' do
  let!(:electronics) { create(:category, name: 'Electronics', slug: 'electronics') }
  let!(:clothing) { create(:category, name: 'Clothing', slug: 'clothing') }
  let!(:home) { create(:category, name: 'Home & Garden', slug: 'home-garden') }

  describe 'GET /api/v1/categories' do
    it 'returns a list of categories' do
      get '/api/v1/categories'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']).to be_an(Array)
      expect(json['data'].length).to eq(3)
    end

    it 'returns categories ordered by name' do
      get '/api/v1/categories'

      json = response.parsed_body
      names = json['data'].map { |c| c['name'] }

      expect(names).to eq(['Clothing', 'Electronics', 'Home & Garden'])
    end

    context 'with with_products filter' do
      before do
        create(:product, category: electronics)
        # clothing has no products
        # home has no products
      end

      it 'returns only categories with products when with_products=true' do
        get '/api/v1/categories', params: { with_products: 'true' }

        json = response.parsed_body
        names = json['data'].map { |c| c['name'] }

        expect(names).to eq(['Electronics'])
      end

      it 'returns all categories when with_products is not set' do
        get '/api/v1/categories'

        json = response.parsed_body

        expect(json['data'].length).to eq(3)
      end
    end
  end

  describe 'GET /api/v1/categories/:id' do
    it 'returns category details by slug' do
      get '/api/v1/categories/electronics'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']['name']).to eq('Electronics')
      expect(json['data']['slug']).to eq('electronics')
    end

    it 'returns category details by id' do
      get "/api/v1/categories/#{electronics.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']['name']).to eq('Electronics')
    end

    it 'returns 404 for non-existent category' do
      get '/api/v1/categories/non-existent-category'

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body

      expect(json['error']['code']).to eq('not_found')
    end
  end
end
