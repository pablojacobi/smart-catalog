# frozen_string_literal: true

module Api
  module V1
    class BrandsController < BaseController
      # GET /api/v1/brands
      def index
        brands = Brand.ordered
        brands = brands.with_products if params[:with_products] == 'true'

        render_collection(brands, blueprint: BrandBlueprint, view: :normal)
      end

      # GET /api/v1/brands/:id
      def show
        brand = find_brand

        render_resource(brand, blueprint: BrandBlueprint, view: :extended)
      end

      private

      def find_brand
        Brand.find_by!(slug: params[:id])
      rescue ActiveRecord::RecordNotFound
        Brand.find(params[:id])
      end
    end
  end
end
