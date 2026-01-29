# frozen_string_literal: true

# Base controller for HTML views
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end
