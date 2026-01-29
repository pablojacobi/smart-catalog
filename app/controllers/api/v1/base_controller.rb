# frozen_string_literal: true

module Api
  module V1
    # Base controller for API endpoints
    # Inherits from ActionController::API for lightweight JSON responses
    class BaseController < ActionController::API
      include ErrorHandler
      include Pagination

      before_action :set_default_format

      private

      def set_default_format
        request.format = :json
      end

      # Render a collection with blueprint serialization
      def render_collection(collection, blueprint:, view: :default, meta: nil)
        render json: {
          data: blueprint.render_as_hash(collection, view: view),
          meta: meta
        }.compact
      end

      # Render a single resource with blueprint serialization
      def render_resource(resource, blueprint:, view: :default, status: :ok)
        render json: {
          data: blueprint.render_as_hash(resource, view: view)
        }, status: status
      end
    end
  end
end
