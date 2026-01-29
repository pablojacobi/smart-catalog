# frozen_string_literal: true

module API
  module V1
    class ProductsController < BaseController
      # GET /api/v1/products
      def index
        query = build_product_query
        result = paginate(query.call)

        render_collection(
          result[:data],
          blueprint: ProductBlueprint,
          view: :normal,
          meta: result[:meta]
        )
      end

      # GET /api/v1/products/:id
      def show
        product = Product.includes(:category, :brand, :document).find(params[:id])

        render_resource(product, blueprint: ProductBlueprint, view: :extended)
      end

      private

      def build_product_query
        ProductQuery.new
          .active
          .with_associations
          .by_category(params[:category_id] || params[:category])
          .by_brand(params[:brand_id] || params[:brand])
          .price_range(params[:min_price], params[:max_price])
          .in_stock(parse_boolean(params[:in_stock]))
          .search(params[:q])
          .sorted_by(sort_field, sort_direction)
      end

      def sort_field
        params[:sort]&.gsub(/_(?:asc|desc)$/, '') || 'name'
      end

      def sort_direction
        params[:sort]&.end_with?('_desc') ? :desc : :asc
      end

      def parse_boolean(value)
        return nil if value.nil?

        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
