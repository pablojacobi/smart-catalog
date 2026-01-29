# frozen_string_literal: true

module API
  module V1
    class BaseController < ApplicationController
      # Inherits ErrorHandler and Pagination from ApplicationController

      private

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
