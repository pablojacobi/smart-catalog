# frozen_string_literal: true

module Chat
  # Service for building chat responses based on query type and results
  # Formats products, handles counts, comparisons, etc.
  class ResponseBuilderService
    include CallableService

    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful product catalog assistant. Format responses clearly and professionally.

      Guidelines:
      - Be concise but informative
      - Use bullet points for lists
      - Include relevant product details (name, price, key specs)
      - For comparisons, create clear side-by-side analysis
      - If no products found, suggest alternatives or clarify the search
      - Always be helpful and professional
    PROMPT

    def initialize(client: nil)
      @client = client || Ai::ProviderService.client
    end

    # Build response based on query type and results
    #
    # @param query_type [String] Type of query (listing, count, etc.)
    # @param products [Array<Product>] Products to include in response
    # @param query [String] Original user query
    # @param context [Hash] Additional context
    # @return [Hash] Response with content and metadata
    def call(query_type:, products:, query:, context: {})
      Rails.logger.info("[ResponseBuilder] Building #{query_type} response with #{products.length} products")

      case query_type
      when 'count'
        build_count_response(products, context)
      when 'comparison'
        build_comparison_response(products, query)
      when 'conversational'
        build_conversational_response(query)
      when 'contextual'
        build_contextual_response(products, query, context)
      else # listing
        build_listing_response(products, query)
      end
    end

    private

    def build_count_response(products, context)
      counts = context[:counts] || { total: products.length }

      content = "## Product Count\n\n"
      content += "**Total: #{counts[:total]} products**\n\n"

      if counts[:by_category].present?
        content += "### By Category:\n"
        counts[:by_category].each do |cat, count|
          content += "- #{cat}: #{count}\n"
        end
        content += "\n"
      end

      if counts[:by_brand].present? && counts[:by_brand].length <= 10
        content += "### By Brand:\n"
        counts[:by_brand].each do |brand, count|
          content += "- #{brand}: #{count}\n"
        end
      end

      {
        content: content,
        product_ids: [],
        response_type: 'count'
      }
    end

    def build_comparison_response(products, query)
      return no_products_response('comparison') if products.empty?

      product_data = products.first(5).map { |p| format_product_for_llm(p) }

      messages = [
        { role: 'user', content: SYSTEM_PROMPT },
        { role: 'assistant', content: 'Understood. I will format responses clearly.' },
        { role: 'user', content: "Compare these products based on the user's query: '#{query}'\n\nProducts:\n#{product_data.join("\n\n")}" }
      ]

      result = @client.generate_content(messages, temperature: 0.7)
      content = result[:content] || 'Unable to generate comparison.'

      {
        content: content,
        product_ids: products.map(&:id),
        response_type: 'comparison'
      }
    end

    def build_conversational_response(query)
      messages = [
        { role: 'user', content: "You are a friendly product catalog assistant. The catalog contains various products with categories, brands, prices, and specifications. Help users find what they need." },
        { role: 'assistant', content: "Hello! I'm here to help you find products." },
        { role: 'user', content: query }
      ]

      result = @client.generate_content(messages, temperature: 0.8)
      content = result[:content] || "Hello! I can help you find products. Try asking about specific categories, brands, or price ranges."

      {
        content: content,
        product_ids: [],
        response_type: 'conversational'
      }
    end

    def build_contextual_response(products, query, _context)
      return no_products_response('contextual') if products.empty?

      product_data = products.first(20).map { |p| format_product_for_llm(p) }

      messages = [
        { role: 'user', content: SYSTEM_PROMPT },
        { role: 'assistant', content: 'Understood.' },
        { role: 'user', content: "Based on these products, answer: '#{query}'\n\nProducts:\n#{product_data.join("\n\n")}" }
      ]

      result = @client.generate_content(messages, temperature: 0.5)
      content = result[:content] || format_products_list(products)

      {
        content: content,
        product_ids: products.map(&:id),
        response_type: 'contextual'
      }
    end

    def build_listing_response(products, query)
      return no_products_response('listing') if products.empty?

      content = "## Products Found\n\n"
      content += "Found **#{products.length}** products matching your search.\n\n"

      products.first(20).each_with_index do |product, index|
        content += format_product_display(product, index + 1)
      end

      if products.length > 20
        content += "\n*...and #{products.length - 20} more products*\n"
      end

      {
        content: content,
        product_ids: products.map(&:id),
        response_type: 'listing'
      }
    end

    def format_product_display(product, index)
      output = "### #{index}. #{product.name}\n"
      output += "- **Brand:** #{product.brand&.name || 'N/A'}\n"
      output += "- **Category:** #{product.category&.name || 'N/A'}\n"
      output += "- **Price:** #{product.formatted_price || 'Contact for price'}\n"

      if product.specifications.present?
        key_specs = product.specifications.first(3).map { |k, v| "#{k}: #{v}" }.join(', ')
        output += "- **Specs:** #{key_specs}\n"
      end

      output += "- **In Stock:** #{product.in_stock ? 'Yes' : 'No'}\n"
      output += "\n"
      output
    end

    def format_product_for_llm(product)
      specs = product.specifications.map { |k, v| "#{k}: #{v}" }.join(', ')

      <<~PRODUCT
        Name: #{product.name}
        Brand: #{product.brand&.name || 'N/A'}
        Category: #{product.category&.name || 'N/A'}
        Price: #{product.formatted_price || 'N/A'}
        Specifications: #{specs.presence || 'N/A'}
        Description: #{product.description&.truncate(200) || 'N/A'}
      PRODUCT
    end

    def no_products_response(type)
      content = case type
                when 'comparison'
                  "I couldn't find products to compare. Try being more specific about what you'd like to compare."
                when 'contextual'
                  "I don't have previous results to reference. Could you start a new search?"
                else
                  "No products found matching your criteria. Try broadening your search or using different keywords."
                end

      {
        content: content,
        product_ids: [],
        response_type: type
      }
    end

    def format_products_list(products)
      products.map { |p| "- #{p.name} (#{p.formatted_price || 'N/A'})" }.join("\n")
    end
  end
end
