# frozen_string_literal: true

module Chat
  # Builds optimized context for LLM including catalog statistics and relevant products
  # Uses Markdown format for token efficiency (34-38% less tokens than JSON)
  class ContextBuilderService
    include CallableService

    MAX_PRODUCTS = 20
    MAX_SPECS = 5

    def initialize(search_service: nil)
      @search_service = search_service || Search::HybridSearchService.new
    end

    # Build context for a query
    # @param query [String] User's query
    # @param filters [Hash] Filters extracted from query classification
    # @return [Hash] Context with :statistics, :products, and :markdown
    def call(query:, filters: {})
      statistics = build_statistics(filters)
      products = search_relevant_products(query, filters)

      {
        statistics: statistics,
        products: products,
        markdown: format_context_markdown(statistics, products)
      }
    end

    private

    def build_statistics(filters)
      base_scope = Product.active

      # Apply filters to scope for relevant statistics
      base_scope = apply_filters(base_scope, filters)

      {
        total: base_scope.count,
        by_category: count_by_association(base_scope, :category),
        by_brand: count_by_association(base_scope, :brand),
        price_range: price_range(base_scope),
        in_stock_count: base_scope.in_stock.count,
        cheapest: cheapest_product(base_scope),
        most_expensive: most_expensive_product(base_scope)
      }
    end

    def apply_filters(scope, filters)
      scope = scope.joins(:category).where(categories: { slug: filters[:category] }) if filters[:category]
      scope = scope.joins(:brand).where(brands: { slug: filters[:brand] }) if filters[:brand]
      scope = scope.where(price: (filters[:min_price])..) if filters[:min_price]
      scope = scope.where(price: ..(filters[:max_price])) if filters[:max_price]
      scope = scope.in_stock if filters[:in_stock]
      scope
    end

    def count_by_association(scope, association)
      scope
        .joins(association)
        .group("#{association.to_s.pluralize}.name")
        .count
        .sort_by { |_, count| -count }
        .first(10)
        .to_h
    end

    def price_range(scope)
      result = scope.where.not(price: nil).pick(Arel.sql('MIN(price)'), Arel.sql('MAX(price)'))
      { min: result&.first, max: result&.last }
    end

    def cheapest_product(scope)
      product = scope.where.not(price: nil).order(:price).first
      format_product_brief(product)
    end

    def most_expensive_product(scope)
      product = scope.where.not(price: nil).order(price: :desc).first
      format_product_brief(product)
    end

    def format_product_brief(product)
      return nil unless product

      { name: product.name, price: product.price, brand: product.brand&.name }
    end

    def search_relevant_products(query, filters)
      results = @search_service.call(
        query: query,
        filters: filters,
        limit: MAX_PRODUCTS
      )

      results.pluck(:product)
    end

    def format_context_markdown(statistics, products)
      markdown = +''

      # Statistics section
      markdown << format_statistics_markdown(statistics)

      # Products section
      markdown << format_products_markdown(products)

      markdown
    end

    def format_statistics_markdown(stats)
      markdown = +"## Catalog Overview\n"
      markdown << "- Total matching products: #{stats[:total]}\n"
      markdown << "- In stock: #{stats[:in_stock_count]}\n"

      if stats[:price_range][:min] && stats[:price_range][:max]
        markdown << "- Price range: $#{stats[:price_range][:min]} - $#{stats[:price_range][:max]}\n"
      end

      markdown << "- Cheapest: #{stats[:cheapest][:name]} ($#{stats[:cheapest][:price]})\n" if stats[:cheapest]

      if stats[:most_expensive]
        markdown << "- Most expensive: #{stats[:most_expensive][:name]} ($#{stats[:most_expensive][:price]})\n"
      end

      # Categories breakdown
      if stats[:by_category].any?
        markdown << "\n### By Category\n"
        stats[:by_category].each { |name, count| markdown << "- #{name}: #{count}\n" }
      end

      # Brands breakdown (top 10)
      if stats[:by_brand].any?
        markdown << "\n### By Brand (top #{stats[:by_brand].size})\n"
        stats[:by_brand].each { |name, count| markdown << "- #{name}: #{count}\n" }
      end

      markdown << "\n"
    end

    def format_products_markdown(products)
      return "## No products found\n" if products.empty?

      markdown = "## Relevant Products (#{products.size})\n"
      markdown << "Format: [Name | Brand | Category | Price | Stock]\n\n"

      products.each_with_index do |product, index|
        markdown << format_single_product(product, index + 1)
      end

      markdown
    end

    def format_single_product(product, index)
      stock_indicator = product.in_stock ? '✓' : '✗'
      price_str = product.price ? "$#{product.price}" : 'N/A'

      line = "#{index}. #{product.name} | "
      line << "#{product.brand&.name || 'N/A'} | "
      line << "#{product.category&.name || 'N/A'} | "
      line << "#{price_str} | #{stock_indicator}\n"

      # Add key specifications
      if product.specifications.present?
        specs = product.specifications.first(MAX_SPECS).map { |k, v| "#{k}: #{v}" }.join(', ')
        line << "   → #{specs}\n"
      end

      line
    end
  end
end
