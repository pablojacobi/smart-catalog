# frozen_string_literal: true

module Search
  # Service for structured SQL search on products
  # Applies exact filters for category, brand, price, etc.
  class SqlSearchService
    include CallableService

    DEFAULT_LIMIT = 100

    # Search products with structured filters
    #
    # @param filters [Hash] Filter criteria
    # @option filters [String] :category Category slug or name
    # @option filters [String] :brand Brand slug or name
    # @option filters [Float] :min_price Minimum price
    # @option filters [Float] :max_price Maximum price
    # @option filters [String] :query Text search in name/description
    # @option filters [Boolean] :in_stock Only in-stock products
    # @option filters [Hash] :specifications Specification key-value filters
    # @param limit [Integer] Maximum results
    # @return [Array<Hash>] Products matching filters
    def call(filters = {}, limit: DEFAULT_LIMIT)
      Rails.logger.info("[SqlSearch] Filters: #{filters.inspect}")
      start_time = Time.current

      scope = Product.active.includes(:category, :brand)

      scope = apply_filters(scope, filters)
      scope = scope.limit(limit)

      products = scope.to_a

      # Format results
      formatted = products.map do |product|
        {
          product: product,
          score: 1.0, # SQL matches are exact
          source: 'sql'
        }
      end

      duration = Time.current - start_time
      Rails.logger.info("[SqlSearch] Found #{formatted.length} results in #{duration.round(2)}s")

      formatted
    end

    # Count products matching filters (for count queries)
    #
    # @param filters [Hash] Filter criteria
    # @return [Hash] Count by various dimensions
    def count(filters = {})
      scope = Product.active
      scope = apply_filters(scope, filters)

      {
        total: scope.count,
        by_category: scope.group('categories.name').joins(:category).count,
        by_brand: scope.group('brands.name').joins(:brand).count,
        in_stock: scope.in_stock.count,
        with_price: scope.with_price.count
      }
    end

    private

    def apply_filters(scope, filters)
      scope = apply_category_filter(scope, filters[:category])
      scope = apply_brand_filter(scope, filters[:brand])
      scope = apply_price_filters(scope, filters[:min_price], filters[:max_price])
      scope = apply_text_search(scope, filters[:query])
      scope = apply_stock_filter(scope, filters[:in_stock])
      apply_specification_filters(scope, filters[:specifications])
    end

    def apply_category_filter(scope, category)
      return scope if category.blank?

      # Normalize category name (handle synonyms/translations)
      normalized_category = normalize_category_name(category)

      category_record = Category.find_by('slug = ? OR name ILIKE ?', normalized_category, normalized_category)
      return scope.none unless category_record

      scope.where(category_id: category_record.id)
    end

    def normalize_category_name(category)
      # Map common synonyms and translations to DB category names
      category_mappings = {
        # Spanish translations
        'computadores' => 'laptops',
        'computadoras' => 'laptops',
        'portatiles' => 'laptops',
        'portátiles' => 'laptops',
        'notebooks' => 'laptops',
        'ordenadores' => 'laptops',
        'tabletas' => 'tablets',
        'accesorios' => 'mobile-accessories',
        'accesorios moviles' => 'mobile-accessories',
        'accesorios móviles' => 'mobile-accessories',
        # English synonyms
        'computers' => 'laptops',
        'notebook' => 'laptops',
        'laptop' => 'laptops',
        'tablet' => 'tablets',
        'accessories' => 'mobile-accessories',
        'mobile accessories' => 'mobile-accessories'
      }

      category_mappings[category.to_s.downcase.strip] || category
    end

    def apply_brand_filter(scope, brand)
      return scope if brand.blank?

      brand_record = Brand.find_by('slug = ? OR name ILIKE ?', brand, brand)
      return scope.none unless brand_record

      scope.where(brand_id: brand_record.id)
    end

    def apply_price_filters(scope, min_price, max_price)
      scope = scope.where(price: min_price..) if min_price.present?
      scope = scope.where(price: ..max_price) if max_price.present?
      scope
    end

    def apply_text_search(scope, query)
      return scope if query.blank?

      scope.where('name ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%")
    end

    def apply_stock_filter(scope, in_stock)
      return scope if in_stock.nil?

      in_stock ? scope.in_stock : scope.where(in_stock: false)
    end

    def apply_specification_filters(scope, specs)
      return scope if specs.blank?

      specs.each do |key, value|
        next if value.blank?

        # Try multiple key variations for flexibility
        possible_keys = specification_key_variations(key)

        # Normalize value - extract numeric part for values like "32GB"
        normalized_value = normalize_spec_value(value)
        search_values = [value, normalized_value].uniq.compact_blank

        # Build OR condition for all possible key+value combinations
        conditions = []
        possible_keys.each do |k|
          search_values.each do |v|
            conditions << scope.where('specifications->>? ILIKE ?', k, "%#{v}%")
          end
        end

        # Combine with OR
        combined = conditions.reduce { |acc, cond| acc.or(cond) }
        scope = combined || scope.none
      end

      scope
    end

    def specification_key_variations(key)
      key_str = key.to_s

      # Map common query terms to DB specification keys
      key_mappings = {
        'graphics_card' => ['gpu'],
        'graphics' => ['gpu'],
        'video_card' => ['gpu'],
        'processor' => ['cpu'],
        'memory' => %w[ram_gb RAM],
        'ram' => ['ram_gb'],
        'storage' => ['storage_gb'],
        'operating_system' => ['os']
      }

      # Start with the original key in different cases
      variations = [key_str, key_str.downcase, key_str.upcase]

      # Add mapped keys if applicable
      variations.concat(key_mappings[key_str.downcase]) if key_mappings[key_str.downcase]

      variations.uniq
    end

    def normalize_spec_value(value)
      # Extract numeric values from strings like "32GB", "16gb", "512GB"
      value.to_s.gsub(/[^\d.]/, '')
    end
  end
end
