# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pagination, type: :controller do
  controller(ApplicationController) do
    include Pagination

    def index
      products = Product.all
      result = paginate(products)

      render json: {
        data: result[:data].map { |p| { id: p.id, name: p.name } },
        meta: result[:meta]
      }
    end

    def pagination_info
      render json: pagination_params
    end
  end

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'pagination_info' => 'anonymous#pagination_info'
    end
  end

  let!(:products) { create_list(:product, 30) }

  describe '#paginate' do
    it 'paginates collection with default values' do
      get :index

      json = response.parsed_body
      expect(json['data'].length).to eq(25) # DEFAULT_PER_PAGE
      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['per_page']).to eq(25)
      expect(json['meta']['total_count']).to eq(30)
    end

    it 'respects page parameter' do
      get :index, params: { page: 2 }

      json = response.parsed_body
      expect(json['data'].length).to eq(5) # remaining items
      expect(json['meta']['current_page']).to eq(2)
    end

    it 'respects per_page parameter' do
      get :index, params: { per_page: 10 }

      json = response.parsed_body
      expect(json['data'].length).to eq(10)
      expect(json['meta']['per_page']).to eq(10)
    end

    it 'limits per_page to MAX_PER_PAGE' do
      get :index, params: { per_page: 200 }

      json = response.parsed_body
      expect(json['meta']['per_page']).to eq(100) # MAX_PER_PAGE
    end

    it 'uses default per_page for invalid values' do
      get :index, params: { per_page: 0 }

      json = response.parsed_body
      expect(json['meta']['per_page']).to eq(25) # DEFAULT_PER_PAGE
    end

    it 'uses default per_page for negative values' do
      get :index, params: { per_page: -5 }

      json = response.parsed_body
      expect(json['meta']['per_page']).to eq(25) # DEFAULT_PER_PAGE
    end

    it 'uses minimum page of 1' do
      get :index, params: { page: 0 }

      json = response.parsed_body
      expect(json['meta']['current_page']).to eq(1)
    end

    it 'uses minimum page of 1 for negative values' do
      get :index, params: { page: -1 }

      json = response.parsed_body
      expect(json['meta']['current_page']).to eq(1)
    end
  end

  describe '#pagination_meta' do
    it 'calculates total_pages correctly' do
      get :index, params: { per_page: 10 }

      json = response.parsed_body
      expect(json['meta']['total_pages']).to eq(3) # 30 items / 10 per page
    end

    it 'sets has_next_page correctly when on first page' do
      get :index, params: { per_page: 10 }

      json = response.parsed_body
      expect(json['meta']['has_next_page']).to be true
    end

    it 'sets has_next_page correctly when on last page' do
      get :index, params: { page: 3, per_page: 10 }

      json = response.parsed_body
      expect(json['meta']['has_next_page']).to be false
    end

    it 'sets has_prev_page correctly when on first page' do
      get :index, params: { page: 1 }

      json = response.parsed_body
      expect(json['meta']['has_prev_page']).to be false
    end

    it 'sets has_prev_page correctly when not on first page' do
      get :index, params: { page: 2 }

      json = response.parsed_body
      expect(json['meta']['has_prev_page']).to be true
    end
  end

  describe '#pagination_params' do
    it 'returns current pagination parameters' do
      get :pagination_info, params: { page: 2, per_page: 15 }

      json = response.parsed_body
      expect(json['page']).to eq(2)
      expect(json['per_page']).to eq(15)
    end
  end
end
