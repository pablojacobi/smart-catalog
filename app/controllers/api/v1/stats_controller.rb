# frozen_string_literal: true

module Api
  module V1
    class StatsController < BaseController
      # GET /api/v1/stats
      def index
        render json: {
          stats: {
            products: product_stats,
            documents: document_stats,
            categories: Category.count,
            brands: Brand.count
          },
          generated_at: Time.current.iso8601
        }
      end

      private

      def product_stats
        {
          total: Product.count,
          active: Product.active.count,
          in_stock: Product.in_stock.count,
          with_price: Product.with_price.count,
          by_category: Product.joins(:category).group('categories.name').count,
          by_brand: Product.joins(:brand).group('brands.name').count
        }
      end

      def document_stats
        {
          total: Document.count,
          pending: Document.pending.count,
          processing: Document.processing.count,
          completed: Document.completed.count,
          failed: Document.failed.count,
          with_embedding: Document.with_embedding.count
        }
      end
    end
  end
end
