# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health Check' do
  describe 'GET /health' do
    context 'when all checks pass' do
      it 'returns healthy status' do
        get '/health'

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json['status']).to eq('healthy')
        expect(json['checks']['database']).to be true
        expect(json['timestamp']).to be_present
      end

      it 'includes version information' do
        get '/health'

        json = response.parsed_body

        expect(json['version']['ruby']).to eq(RUBY_VERSION)
        expect(json['version']['rails']).to eq(Rails.version)
        expect(json['version']['app']).to be_present
      end

      it 'includes environment' do
        get '/health'

        json = response.parsed_body

        expect(json['environment']).to be_present
      end

      it 'includes stats' do
        get '/health'

        json = response.parsed_body

        expect(json['stats']).to have_key('products')
        expect(json['stats']).to have_key('categories')
        expect(json['stats']).to have_key('brands')
      end
    end

    context 'when database is unhealthy' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad)
      end

      it 'returns unhealthy status' do
        get '/health'

        expect(response).to have_http_status(:service_unavailable)
        json = response.parsed_body

        expect(json['status']).to eq('unhealthy')
        expect(json['checks']['database']).to be false
      end
    end

    context 'when migrations check fails' do
      before do
        allow_any_instance_of(HealthController).to receive(:migrations_check).and_return(false) # rubocop:disable RSpec/AnyInstance
      end

      it 'returns unhealthy status' do
        get '/health'

        expect(response).to have_http_status(:service_unavailable)
        json = response.parsed_body

        expect(json['status']).to eq('unhealthy')
        expect(json['checks']['migrations']).to be false
      end
    end

    context 'when stats check fails' do
      before do
        allow(Product).to receive(:count).and_raise(StandardError)
      end

      it 'returns empty stats but still healthy' do
        get '/health'

        json = response.parsed_body

        expect(json['stats']).to eq({})
        # Status is still healthy because stats failure is not critical
        expect(json['status']).to eq('healthy')
      end
    end
  end
end
