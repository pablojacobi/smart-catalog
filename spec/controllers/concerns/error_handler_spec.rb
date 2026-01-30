# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ErrorHandler, type: :controller do
  # Create a test controller that includes the ErrorHandler concern
  controller(ActionController::API) do
    include ErrorHandler
    def record_not_found
      raise ActiveRecord::RecordNotFound, 'Product not found'
    end

    def validation_error
      product = Product.new
      product.errors.add(:name, "can't be blank")
      raise ActiveRecord::RecordInvalid, product
    end

    def smart_catalog_not_found
      raise SmartCatalog::NotFoundError.new('Custom not found')
    end

    def smart_catalog_validation
      raise SmartCatalog::ValidationError.new('Custom validation error', details: ['field is invalid'])
    end

    def standard_error
      raise StandardError, 'Something unexpected'
    end

    def parameter_missing
      raise ActionController::ParameterMissing, :required_param
    end

    def authentication_error
      raise SmartCatalog::AuthenticationError.new('Invalid API key')
    end

    def rate_limit_error
      raise SmartCatalog::RateLimitError.new('Too many requests')
    end

    def service_unavailable_error
      raise SmartCatalog::ServiceUnavailableError.new('Service down')
    end

    def success_response
      render_success(data: { id: 1, name: 'Test' }, status: :created, message: 'Created successfully', meta: { page: 1 })
    end

    def simple_success
      render_success(data: { id: 1 })
    end
  end

  before do
    routes.draw do
      get 'record_not_found' => 'anonymous#record_not_found'
      get 'validation_error' => 'anonymous#validation_error'
      get 'smart_catalog_not_found' => 'anonymous#smart_catalog_not_found'
      get 'smart_catalog_validation' => 'anonymous#smart_catalog_validation'
      get 'standard_error' => 'anonymous#standard_error'
      get 'parameter_missing' => 'anonymous#parameter_missing'
      get 'authentication_error' => 'anonymous#authentication_error'
      get 'rate_limit_error' => 'anonymous#rate_limit_error'
      get 'service_unavailable_error' => 'anonymous#service_unavailable_error'
      get 'success_response' => 'anonymous#success_response'
      get 'simple_success' => 'anonymous#simple_success'
    end
  end

  describe 'ActiveRecord::RecordNotFound' do
    it 'returns 404 with error message' do
      get :record_not_found

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json['error']['message']).to eq('Product not found')
      expect(json['error']['code']).to eq('not_found')
    end
  end

  describe 'ActiveRecord::RecordInvalid' do
    it 'returns 422 with validation errors' do
      get :validation_error

      expect(response).to have_http_status(:unprocessable_content)
      json = response.parsed_body
      expect(json['error']['code']).to eq('validation_error')
      expect(json['error']['details']).to include("Name can't be blank")
    end
  end

  describe 'SmartCatalog::NotFoundError' do
    it 'returns 404 with custom message' do
      get :smart_catalog_not_found

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json['error']['message']).to eq('Custom not found')
    end
  end

  describe 'SmartCatalog::ValidationError' do
    it 'returns 422 with details' do
      get :smart_catalog_validation

      expect(response).to have_http_status(:unprocessable_content)
      json = response.parsed_body
      expect(json['error']['message']).to eq('Custom validation error')
      expect(json['error']['details']).to include('field is invalid')
    end
  end

  describe 'StandardError' do
    it 'returns 500 in development with message' do
      allow(Rails.env).to receive(:production?).and_return(false)

      get :standard_error

      expect(response).to have_http_status(:internal_server_error)
      json = response.parsed_body
      expect(json['error']['message']).to eq('Something unexpected')
    end

    it 'returns generic message in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      get :standard_error

      expect(response).to have_http_status(:internal_server_error)
      json = response.parsed_body
      expect(json['error']['message']).to eq('An unexpected error occurred')
    end
  end

  describe 'ActionController::ParameterMissing' do
    it 'returns 400 with parameter info' do
      get :parameter_missing

      expect(response).to have_http_status(:bad_request)
      json = response.parsed_body
      expect(json['error']['code']).to eq('parameter_missing')
      expect(json['error']['message']).to include('required_param')
    end
  end

  describe 'SmartCatalog::AuthenticationError' do
    it 'returns 401 unauthorized' do
      get :authentication_error

      expect(response).to have_http_status(:unauthorized)
      json = response.parsed_body
      expect(json['error']['message']).to eq('Invalid API key')
      expect(json['error']['code']).to eq('authentication_error')
    end
  end

  describe 'SmartCatalog::RateLimitError' do
    it 'returns 429 too many requests' do
      get :rate_limit_error

      expect(response).to have_http_status(:too_many_requests)
      json = response.parsed_body
      expect(json['error']['message']).to eq('Too many requests')
      expect(json['error']['code']).to eq('rate_limit_exceeded')
    end
  end

  describe 'SmartCatalog::ServiceUnavailableError' do
    it 'returns 503 service unavailable' do
      get :service_unavailable_error

      expect(response).to have_http_status(:service_unavailable)
      json = response.parsed_body
      expect(json['error']['message']).to eq('Service down')
      expect(json['error']['code']).to eq('service_unavailable')
    end
  end

  describe '#render_success' do
    it 'renders success with all options' do
      get :success_response

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['data']).to eq({ 'id' => 1, 'name' => 'Test' })
      expect(json['message']).to eq('Created successfully')
      expect(json['meta']).to eq({ 'page' => 1 })
    end

    it 'renders simple success without optional params' do
      get :simple_success

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data']).to eq({ 'id' => 1 })
      expect(json).not_to have_key('message')
      expect(json).not_to have_key('meta')
    end
  end
end
