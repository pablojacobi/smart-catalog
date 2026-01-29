# frozen_string_literal: true

# Controller for the public landing page
class HomeController < ApplicationController
  def index
    # Redirect to chat if user is already logged in
    redirect_to chat_path if user_signed_in?
  end
end
