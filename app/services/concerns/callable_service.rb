# frozen_string_literal: true

# Concern that provides a callable interface for services
# Usage: include CallableService in your service class
# Then call YourService.call(args) instead of YourService.new(args).call
module CallableService
  extend ActiveSupport::Concern

  class_methods do
    def call(...)
      new(...).call
    end
  end
end
