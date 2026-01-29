# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Documents' do
  describe 'GET /api/v1/documents' do
    let!(:completed_doc) { create(:document, filename: 'catalog.pdf', status: 'completed') }
    let!(:pending_doc) { create(:document, filename: 'new.pdf', status: 'pending') }
    let!(:failed_doc) { create(:document, filename: 'broken.pdf', status: 'failed') }

    it 'returns list of documents' do
      get '/api/v1/documents'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']).to be_an(Array)
      expect(json['data'].length).to eq(3)
    end

    it 'filters by status' do
      get '/api/v1/documents', params: { status: 'completed' }

      json = response.parsed_body
      filenames = json['data'].pluck('filename')

      expect(filenames).to include('catalog.pdf')
      expect(filenames).not_to include('new.pdf', 'broken.pdf')
    end

    it 'searches by filename' do
      get '/api/v1/documents', params: { q: 'catalog' }

      json = response.parsed_body

      expect(json['data'].length).to eq(1)
      expect(json['data'].first['filename']).to eq('catalog.pdf')
    end

    it 'includes pagination metadata' do
      get '/api/v1/documents', params: { page: 1, per_page: 2 }

      json = response.parsed_body

      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['total_count']).to eq(3)
    end
  end

  describe 'GET /api/v1/documents/:id' do
    let(:document) { create(:document, :with_products) }

    it 'returns document with products' do
      get "/api/v1/documents/#{document.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json['data']['id']).to eq(document.id)
      expect(json['data']['products']).to be_present
    end

    it 'returns 404 for non-existent document' do
      get '/api/v1/documents/non-existent'

      expect(response).to have_http_status(:not_found)
    end
  end
end
