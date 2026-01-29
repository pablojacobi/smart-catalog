# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ErrorHandler
  include Pagination

  before_action :set_default_format

  private

  def set_default_format
    request.format = :json
  end
end
