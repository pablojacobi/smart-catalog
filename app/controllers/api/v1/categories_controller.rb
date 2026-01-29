# frozen_string_literal: true

module API
  module V1
    class CategoriesController < BaseController
      # GET /api/v1/categories
      def index
        categories = Category.ordered
        categories = categories.with_products if params[:with_products] == 'true'

        render_collection(categories, blueprint: CategoryBlueprint, view: :normal)
      end

      # GET /api/v1/categories/:id
      def show
        category = find_category

        render_resource(category, blueprint: CategoryBlueprint, view: :extended)
      end

      private

      def find_category
        Category.find_by!(slug: params[:id])
      rescue ActiveRecord::RecordNotFound
        Category.find(params[:id])
      end
    end
  end
end
