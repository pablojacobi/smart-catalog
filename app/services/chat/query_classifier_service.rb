# frozen_string_literal: true

module Chat
  # Service for classifying user queries using GPT
  # Extracts intent and structured filters from natural language
  class QueryClassifierService
    include CallableService

    SYSTEM_PROMPT = <<~PROMPT
      You are a query classifier for a product catalog system. Analyze the user's query and extract:

      1. Query type (exactly one):
         - listing: User wants to see products (e.g., "show me laptops", "what phones do you have")
         - count: User wants to know quantities (e.g., "how many", "count of")
         - comparison: User wants to compare products (e.g., "compare X vs Y", "difference between")
         - contextual: Query references previous results (e.g., "from those", "which of these", "the cheaper one")
         - conversational: Greetings or general questions (e.g., "hello", "what can you do")

      2. Filters (extract if present):
         - category: Product category mentioned
         - brand: Brand name mentioned
         - min_price: Minimum price (number only)
         - max_price: Maximum price (number only)
         - in_stock: true if user wants only in-stock items
         - specifications: Key-value pairs for technical specs

      3. Search query: The semantic search terms (clean, relevant keywords)

      Return JSON with this exact structure:
      {
        "query_type": "listing|count|comparison|contextual|conversational",
        "filters": {
          "category": null or string,
          "brand": null or string,
          "min_price": null or number,
          "max_price": null or number,
          "in_stock": null or boolean,
          "specifications": {} or {key: value}
        },
        "search_query": "extracted search terms"
      }
    PROMPT

    def initialize(client: nil)
      @client = client || Gemini::ClientService.new
    end

    # Classify a user query
    #
    # @param query [String] User's natural language query
    # @param context [Hash] Additional context (e.g., previous products)
    # @return [Hash] Classification result
    def call(query, context: {})
      return default_classification if query.blank?

      Rails.logger.info("[QueryClassifier] Classifying: '#{query.truncate(80)}'")

      messages = build_messages(query, context)
      result = @client.generate_content(messages, temperature: 0.1)

      content = result[:content]
      classification = parse_classification(content)

      Rails.logger.info("[QueryClassifier] Type: #{classification[:query_type]}, Filters: #{classification[:filters].compact}")

      classification
    rescue SmartCatalog::Error => e
      Rails.logger.error("[QueryClassifier] Error: #{e.message}")
      fallback_classification(query)
    end

    private

    def build_messages(query, context)
      messages = []

      # System prompt as first user message (Gemini style)
      system_content = SYSTEM_PROMPT
      if context[:previous_products].present?
        system_content += "\n\nPrevious results included #{context[:previous_products].count} products: #{context[:previous_products].map(&:name).first(5).join(', ')}..."
      end

      messages << { role: 'user', content: system_content }
      messages << { role: 'assistant', content: 'Understood. I will classify the query and return JSON.' }
      messages << { role: 'user', content: "Classify this query and respond ONLY with valid JSON:\n\n#{query}" }
      messages
    end

    def parse_classification(content)
      return default_classification if content.blank?

      # Extract JSON from markdown code blocks if present
      json_content = extract_json_from_response(content)

      parsed = JSON.parse(json_content)

      {
        query_type: parsed['query_type'] || 'listing',
        filters: normalize_filters(parsed['filters']),
        search_query: parsed['search_query'] || ''
      }
    rescue JSON::ParserError => e
      Rails.logger.warn("[QueryClassifier] JSON parse error: #{e.message}, content: #{content.truncate(200)}")
      default_classification
    end

    def extract_json_from_response(content)
      # Try to extract JSON from markdown code blocks
      if content.include?('```')
        # Match ```json ... ``` or ``` ... ```
        match = content.match(/```(?:json)?\s*\n?(.*?)\n?```/m)
        return match[1].strip if match
      end

      # If no code block, try to find raw JSON
      if content.strip.start_with?('{')
        content.strip
      else
        # Try to find JSON object anywhere in the content
        match = content.match(/\{[^}]*"query_type"[^}]*\}/m)
        match ? match[0] : content.strip
      end
    end

    def normalize_filters(filters)
      return {} unless filters.is_a?(Hash)

      {
        category: filters['category']&.to_s&.strip.presence,
        brand: filters['brand']&.to_s&.strip.presence,
        min_price: parse_number(filters['min_price']),
        max_price: parse_number(filters['max_price']),
        in_stock: filters['in_stock'],
        specifications: filters['specifications'].is_a?(Hash) ? filters['specifications'] : {}
      }.compact
    end

    def parse_number(value)
      return nil if value.blank?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    def default_classification
      {
        query_type: 'listing',
        filters: {},
        search_query: ''
      }
    end

    def fallback_classification(query)
      # Simple regex-based fallback when GPT fails
      type = case query.downcase
             when /how many|count|cuant/i then 'count'
             when /compare|vs|versus|difference/i then 'comparison'
             when /hello|hi|hey|hola|help/i then 'conversational'
             when /from those|these|which one|that one/i then 'contextual'
             else 'listing'
             end

      {
        query_type: type,
        filters: {},
        search_query: query
      }
    end
  end
end
