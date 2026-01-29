# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Brands' do
  let!(:apple) { create(:brand, name: 'Apple', slug: 'apple') }
  let!(:samsung) { create(:brand, name: 'Samsung', slug: 'samsung') }
  let!(:sony) { create(:brand, name: 'Sony', slug: 'sony') }

  describe 'GET /api/v1/brands' do
    it 'returns a list of brands' do
      get '/api/v1/brands'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']).to be_an(Array)
      expect(json['data'].length).to eq(3)
    end

    it 'returns brands ordered by name' do
      get '/api/v1/brands'

      json = response.parsed_body
      names = json['data'].pluck('name')

      expect(names).to eq(%w[Apple Samsung Sony])
    end

    context 'with with_products filter' do
      before do
        create(:product, brand: apple)
        # samsung has no products
        # sony has no products
      end

      it 'returns only brands with products when with_products=true' do
        get '/api/v1/brands', params: { with_products: 'true' }

        json = response.parsed_body
        names = json['data'].pluck('name')

        expect(names).to eq(['Apple'])
      end

      it 'returns all brands when with_products is not set' do
        get '/api/v1/brands'

        json = response.parsed_body

        expect(json['data'].length).to eq(3)
      end
    end
  end

  describe 'GET /api/v1/brands/:id' do
    it 'returns brand details by slug' do
      get '/api/v1/brands/apple'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']['name']).to eq('Apple')
      expect(json['data']['slug']).to eq('apple')
    end

    it 'returns brand details by id' do
      get "/api/v1/brands/#{apple.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']['name']).to eq('Apple')
    end

    it 'returns 404 for non-existent brand' do
      get '/api/v1/brands/non-existent-brand'

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body

      expect(json['error']['code']).to eq('not_found')
    end
  end
end
