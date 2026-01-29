# frozen_string_literal: true

module Search
  # Hybrid search combining vector similarity with SQL filters
  # Uses intelligent merge strategy for optimal results
  class HybridSearchService
    include CallableService

    DEFAULT_LIMIT = 50

    def initialize(vector_service: nil, sql_service: nil)
      @vector_service = vector_service || VectorSearchService.new
      @sql_service = sql_service || SqlSearchService.new
    end

    # Perform hybrid search combining semantic and structured approaches
    #
    # @param query [String] Natural language query
    # @param filters [Hash] Structured filters extracted from query
    # @param limit [Integer] Maximum results
    # @return [Array<Hash>] Merged and ranked results
    def call(query:, filters: {}, limit: DEFAULT_LIMIT)
      Rails.logger.info("[HybridSearch] Query: '#{query.truncate(60)}', Filters: #{filters.inspect}")
      start_time = Time.current

      # Determine search strategy
      has_filters = filters.values.any?(&:present?)
      has_query = query.present?

      results = if has_filters && !has_query
                  # Only filters - use SQL search
                  sql_only_search(filters, limit)
                elsif has_query && !has_filters
                  # Only query - use vector search
                  vector_only_search(query, limit)
                else
                  # Both - hybrid merge
                  hybrid_merge(query, filters, limit)
                end

      duration = Time.current - start_time
      Rails.logger.info("[HybridSearch] Returned #{results.length} results in #{duration.round(2)}s")

      results
    end

    private

    def sql_only_search(filters, limit)
      sql_results = @sql_service.call(filters, limit: limit)

      sql_results.map do |result|
        build_result(result[:product], result[:score], 'sql')
      end
    end

    def vector_only_search(query, limit)
      vector_results = @vector_service.call(query, limit: limit)

      # Get products from matched documents
      document_ids = vector_results.map { |r| r[:document].id }
      products = Product.active.where(document_id: document_ids).includes(:category, :brand)

      # Map products with document scores
      doc_scores = vector_results.to_h { |r| [r[:document].id, r[:score]] }

      results = products.map do |product|
        score = doc_scores[product.document_id] || 0.5
        build_result(product, score, 'vector')
      end

      results.sort_by { |r| -r[:score] }.first(limit)
    end

    def hybrid_merge(query, filters, limit)
      # Execute both searches in parallel (conceptually)
      vector_results = @vector_service.call(query, limit: limit * 2)
      sql_results = @sql_service.call(filters, limit: limit * 2)

      # Get all relevant products
      sql_product_ids = sql_results.pluck(:product).map(&:id)

      # Build score maps
      vector_scores = build_vector_score_map(vector_results)
      sql_products = sql_results.to_h { |r| [r[:product].id, r[:product]] }

      # Merge strategy depends on filter types
      merged = merge_results(
        vector_scores: vector_scores,
        sql_product_ids: sql_product_ids,
        sql_products: sql_products,
        filters: filters
      )

      merged.sort_by { |r| -r[:score] }.first(limit)
    end

    def build_vector_score_map(vector_results)
      scores = {}
      vector_results.each do |result|
        doc = result[:document]
        doc.products.each do |product|
          scores[product.id] = [scores[product.id] || 0, result[:score]].max
        end
      end
      scores
    end

    def merge_results(vector_scores:, sql_product_ids:, sql_products:, filters:) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      results = []

      # Strict intersection for category/brand filters
      strict_filters = %i[category brand].any? { |f| filters[f].present? }

      if strict_filters
        # Only include products that match SQL filters
        sql_product_ids.each do |product_id|
          product = sql_products[product_id]
          vector_score = vector_scores[product_id] || 0

          # Boost if also found in vector search
          final_score = vector_score > 0 ? (1.0 + vector_score) / 2.0 : 0.8
          results << build_result(product, final_score, 'hybrid')
        end
      else
        # Flexible union for price/other filters
        all_product_ids = (vector_scores.keys + sql_product_ids).uniq
        products = Product.active.where(id: all_product_ids).includes(:category, :brand).index_by(&:id)

        all_product_ids.each do |product_id|
          product = products[product_id] || sql_products[product_id]
          next unless product

          vector_score = vector_scores[product_id] || 0
          sql_match = sql_product_ids.include?(product_id)

          # Combined scoring
          final_score = if vector_score > 0 && sql_match
                          (vector_score + 1.0) / 2.0 # Both matched - highest score
                        elsif sql_match
                          0.8 # SQL only
                        else
                          vector_score * 0.9 # Vector only - slight penalty
                        end

          results << build_result(product, final_score, 'hybrid')
        end
      end

      results
    end

    def build_result(product, score, source)
      {
        product: product,
        score: score.round(4),
        source: source
      }
    end
  end
end
