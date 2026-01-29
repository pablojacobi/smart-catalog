# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::Sessions' do
  let(:user) { create(:user) }

  describe 'GET /users/sign_in' do
    it 'renders the login page' do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
    end

    it 'includes email and password fields' do
      get new_user_session_path
      expect(response.body).to include('type="email"')
      expect(response.body).to include('type="password"')
    end

    it 'includes SmartCatalog branding' do
      get new_user_session_path
      expect(response.body).to include('SmartCatalog')
    end

    it 'includes sign in button' do
      get new_user_session_path
      expect(response.body).to include('Sign in')
    end
  end

  describe 'POST /users/sign_in' do
    context 'with invalid credentials' do
      it 'does not sign in and re-renders the login page' do
        post user_session_path, params: {
          user: { email: user.email, password: 'wrong_password' }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not authenticate user with wrong email' do
        post user_session_path, params: {
          user: { email: 'wrong@email.com', password: user.password }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'authentication flow' do
    it 'redirects unauthenticated users from chat to sign in' do
      get '/chat'
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'allows authenticated users to access chat' do
      sign_in user
      get '/chat'
      expect(response).to have_http_status(:ok)
    end
  end
end
