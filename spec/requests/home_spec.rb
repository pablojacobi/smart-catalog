# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home' do
  describe 'GET /' do
    context 'when not authenticated' do
      it 'renders the landing page' do
        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('SmartCatalog')
        expect(response.body).to include('Natural Language')
      end

      it 'shows sign in link' do
        get root_path

        expect(response.body).to include('Sign In')
      end

      it 'shows GitHub link' do
        get root_path

        expect(response.body).to include('github.com/pablojacobi/smart-catalog')
      end

      it 'shows example queries' do
        get root_path

        expect(response.body).to include('Show me all tablets')
        expect(response.body).to include('Laptops under $1000')
      end
    end

    context 'when authenticated' do
      let(:user) { create(:user) }

      before { sign_in user }

      it 'redirects to chat' do
        get root_path

        expect(response).to redirect_to(chat_path)
      end
    end
  end
end
